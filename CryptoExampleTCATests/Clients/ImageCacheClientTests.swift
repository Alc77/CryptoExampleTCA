import Dependencies
import Foundation
import Testing
import UIKit

extension BaseSuite {
    @Suite struct ImageCacheClientTests {

        // MARK: Helpers

        /// A throwaway directory unique to each test; never the real caches directory.
        private static func makeTempDirectory() -> URL {
            FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        }

        /// A small solid-color PNG generated in-process (no bundled fixture — the hostless
        /// bundle has no reliable `Bundle.main` resources).
        private static func makePNG(side: CGFloat = 12) -> Data {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
            let image = renderer.image { context in
                UIColor.orange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
            return image.pngData() ?? Data()
        }

        private static func totalSize(of directory: URL) -> Int {
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { return 0 }
            return files.reduce(0) { sum, file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return sum + size
            }
        }

        private static func fileCount(in directory: URL) -> Int {
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).count) ?? 0
        }

        // MARK: Tests

        /// AC3: a cache miss fetches the bytes via `httpClient`, decodes them, and writes to disk.
        @Test func cacheMissFetchesAndWrites() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/btc/large.png"))
            let png = Self.makePNG()

            let image = try await withDependencies {
                $0.httpClient = HTTPClient { _ in png }
            } operation: {
                try await ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000).image(url)
            }

            #expect(image.size.width > 0)
            #expect(Self.fileCount(in: dir) == 1)
        }

        /// AC2: with the image already on disk, `image(url:)` returns it without any network request.
        @Test func cacheHitSkipsNetwork() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/eth/large.png"))
            let png = Self.makePNG()
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)

            // Seed the cache via a first (miss) fetch.
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(url)
            }

            // Second call must hit disk and never touch the network.
            let callCount = LockIsolated(0)
            let image = try await withDependencies {
                $0.httpClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(url)
            }

            #expect(image.size.width > 0)
            #expect(callCount.value == 0)
        }

        /// AC4 (NFR8): writing past the size limit evicts oldest-first back under the limit.
        @Test func evictionKeepsUnderLimit() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let png = Self.makePNG()
            // Limit large enough for one image but not two.
            let maxBytes = png.count + png.count / 2
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: maxBytes)

            let oldURL = try #require(URL(string: "https://coin-images.example/old/large.png"))
            let newURL = try #require(URL(string: "https://coin-images.example/new/large.png"))

            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(oldURL)
            }
            // Ensure the newer file has a strictly later modification date.
            try await Task.sleep(for: .milliseconds(20))
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(newURL)
            }

            // Oldest evicted → exactly one file remains, within the limit.
            #expect(Self.fileCount(in: dir) == 1)
            #expect(Self.totalSize(of: dir) <= maxBytes)

            // The surviving entry is the newer one (cache hit → no network).
            let callCount = LockIsolated(0)
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(newURL)
            }
            #expect(callCount.value == 0)
        }

        /// AC5: undecodable bytes throw `decodingFailed` and write nothing to disk.
        @Test func decodeFailureThrowsAndWritesNothing() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/bad/large.png"))
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)

            await #expect(throws: ImageCacheError.decodingFailed) {
                try await withDependencies {
                    $0.httpClient = HTTPClient { _ in Data("not an image".utf8) }
                } operation: {
                    try await client.image(url)
                }
            }

            #expect(Self.fileCount(in: dir) == 0)
        }
    }
}

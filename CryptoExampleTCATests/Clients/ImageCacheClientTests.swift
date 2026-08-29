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

        /// Forces every cached file to a fixed modification date so eviction ordering is
        /// deterministic without relying on wall-clock timing between writes.
        private static func setModificationDate(_ date: Date, forFilesIn directory: URL) {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { return }
            for file in files {
                try? FileManager.default.setAttributes(
                    [.modificationDate: date],
                    ofItemAtPath: file.path
                )
            }
        }

        /// Overwrites every cached file with bytes that do not decode to a `UIImage`.
        private static func corruptFiles(in directory: URL) {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { return }
            for file in files {
                try? Data("not an image".utf8).write(to: file)
            }
        }

        // MARK: Tests

        /// AC3: a cache miss fetches the bytes via `imageHTTPClient`, decodes them, and writes to disk —
        /// and the bytes written round-trip exactly to what was fetched.
        @Test func cacheMissFetchesAndWrites() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/btc/large.png"))
            let png = Self.makePNG()

            let image = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000).image(url)
            }

            #expect(image.size.width > 0)
            #expect(Self.fileCount(in: dir) == 1)

            // The stored bytes must be exactly the fetched bytes (not garbage that merely lands a file).
            let storedFile = try #require(
                try FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil
                ).first
            )
            #expect(try Data(contentsOf: storedFile) == png)
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
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(url)
            }

            // Second call must hit disk and never touch the network.
            let callCount = LockIsolated(0)
            let image = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(url)
            }

            #expect(image.size.width > 0)
            #expect(callCount.value == 0)
        }

        /// P1: two concurrent requests for the same uncached URL coalesce into a single network fetch.
        @Test func concurrentSameURLRequestsCoalesceToOneFetch() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/sol/large.png"))
            let png = Self.makePNG()
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)
            let callCount = LockIsolated(0)

            try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    // Hold the fetch open so both requests are genuinely in flight together.
                    try await Task.sleep(for: .milliseconds(30))
                    return png
                }
            } operation: {
                async let first = client.image(url)
                async let second = client.image(url)
                let (imageA, imageB) = try await (first, second)
                #expect(imageA.size.width > 0)
                #expect(imageB.size.width > 0)
            }

            #expect(callCount.value == 1)
            #expect(Self.fileCount(in: dir) == 1)
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
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(oldURL)
            }
            // Force the first entry strictly older — deterministic, no wall-clock sleep.
            Self.setModificationDate(.distantPast, forFilesIn: dir)
            _ = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(newURL)
            }

            // Oldest evicted → exactly one file remains, within the limit.
            #expect(Self.fileCount(in: dir) == 1)
            #expect(Self.totalSize(of: dir) <= maxBytes)

            // The surviving entry is the newer one (cache hit → no network).
            let callCount = LockIsolated(0)
            _ = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(newURL)
            }
            #expect(callCount.value == 0)
        }

        /// P2: an item larger than the whole limit is NOT self-evicted — the just-written entry is
        /// protected, so it persists and serves a subsequent cache hit instead of vanishing.
        @Test func itemLargerThanLimitIsNotSelfEvicted() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/big/large.png"))
            let png = Self.makePNG()
            // A limit deliberately smaller than a single image.
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: png.count / 2)

            _ = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(url)
            }

            #expect(Self.fileCount(in: dir) == 1)

            // It persisted → the next request is a cache hit with no network call.
            let callCount = LockIsolated(0)
            _ = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(url)
            }
            #expect(callCount.value == 0)
        }

        /// P6: a cached file whose bytes no longer decode falls through to the network and self-heals.
        @Test func corruptCachedFileTriggersRefetch() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/corrupt/large.png"))
            let png = Self.makePNG()
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)

            // Seed a valid cache entry, then corrupt the bytes on disk.
            _ = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await client.image(url)
            }
            Self.corruptFiles(in: dir)

            // Undecodable disk bytes → refetch exactly once, then decode succeeds.
            let callCount = LockIsolated(0)
            let image = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in
                    callCount.withValue { $0 += 1 }
                    return png
                }
            } operation: {
                try await client.image(url)
            }

            #expect(image.size.width > 0)
            #expect(callCount.value == 1)
        }

        /// P5: `clearCache` removes every file in the cache directory.
        @Test func clearCacheRemovesAllFiles() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let png = Self.makePNG()
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)

            let first = try #require(URL(string: "https://coin-images.example/a/large.png"))
            let second = try #require(URL(string: "https://coin-images.example/b/large.png"))
            for url in [first, second] {
                _ = try await withDependencies {
                    $0.imageHTTPClient = HTTPClient { _ in png }
                } operation: {
                    try await client.image(url)
                }
            }
            #expect(Self.fileCount(in: dir) == 2)

            await client.clearCache()

            #expect(Self.fileCount(in: dir) == 0)
        }

        /// AC5: undecodable bytes throw `decodingFailed` and write nothing to disk.
        @Test func decodeFailureThrowsAndWritesNothing() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/bad/large.png"))
            let client = ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000)

            await #expect(throws: ImageCacheError.decodingFailed) {
                try await withDependencies {
                    $0.imageHTTPClient = HTTPClient { _ in Data("not an image".utf8) }
                } operation: {
                    try await client.image(url)
                }
            }

            #expect(Self.fileCount(in: dir) == 0)
        }

        /// Review D3: image fetches must go through the headerless `\.imageHTTPClient`, never the
        /// API-keyed `\.httpClient` — otherwise the CoinGecko key rides along to third-party image
        /// hosts named by unvalidated `CoinModel.image` values.
        @Test func imageFetchNeverUsesTheAPIKeyedClient() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/key/large.png"))
            let png = Self.makePNG()
            let apiClientCalls = LockIsolated(0)

            let image = try await withDependencies {
                $0.httpClient = HTTPClient { _ in
                    apiClientCalls.withValue { $0 += 1 }
                    return png
                }
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await ImageCacheClient.live(cacheDirectory: dir, maxBytes: 50_000).image(url)
            }

            #expect(image.size.width > 0)
            #expect(apiClientCalls.value == 0)
        }

        /// Review D2: an icon larger than `maxIconPixelSize` is decoded down to it, so the
        /// never-evicted `HomeFeature.State.images` dictionary cannot accumulate full-resolution
        /// bitmaps for a 30pt slot. The bytes on disk are unaffected — only the decode is capped.
        @Test func oversizedImageIsDownsampledOnDecode() async throws {
            let dir = Self.makeTempDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = try #require(URL(string: "https://coin-images.example/big/large.png"))
            let png = Self.makePNG(side: 400)

            let image = try await withDependencies {
                $0.imageHTTPClient = HTTPClient { _ in png }
            } operation: {
                try await ImageCacheClient.live(cacheDirectory: dir, maxBytes: 5_000_000).image(url)
            }

            let longestEdge = max(image.size.width, image.size.height)
            #expect(longestEdge > 0)
            #expect(longestEdge <= CGFloat(ImageCacheClient.maxIconPixelSize))
        }
    }
}

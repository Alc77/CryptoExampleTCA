import CryptoKit
import Dependencies
import Foundation
import UIKit

// MARK: - Error

enum ImageCacheError: Error, Equatable {
    case decodingFailed
}

// MARK: - Client Interface

struct ImageCacheClient {
    var image: @Sendable (URL) async throws -> UIImage
    var clearCache: @Sendable () async -> Void
}

// MARK: - Live Implementation

extension ImageCacheClient {
    /// Factory seam: injecting `cacheDirectory` lets tests point at a throwaway temp
    /// directory instead of the real caches directory (mirrors `HTTPClient.live(apiKey:)`).
    static func live(
        cacheDirectory: URL,
        maxBytes: Int
    ) -> ImageCacheClient {
        let cache = ImageDiskCache(directory: cacheDirectory, maxBytes: maxBytes)
        return ImageCacheClient(
            image: { url in
                // AC2: disk hit → return without any network request.
                if let data = await cache.cachedData(for: url),
                   let image = UIImage(data: data) {
                    return image
                }
                // AC3: miss → fetch bytes via httpClient, resolved at call time so tests
                // can override it via `withDependencies { $0.httpClient = ... }`.
                @Dependency(\.httpClient) var httpClient
                let data = try await httpClient.execute(URLRequest(url: url))
                guard let image = UIImage(data: data) else {
                    throw ImageCacheError.decodingFailed // AC5: decode fails → nothing written
                }
                await cache.store(data: data, for: url) // AC3 write + AC4 eviction
                return image
            },
            clearCache: { await cache.clear() }
        )
    }
}

// MARK: - Disk Cache Engine

/// Owns all `FileManager` I/O for the image cache. Stores/returns `Data` only — decoding to
/// the non-`Sendable` `UIImage` happens in the `image` closure, keeping the actor boundary clean
/// under Swift 6 strict concurrency.
private actor ImageDiskCache {
    let directory: URL
    let maxBytes: Int

    init(directory: URL, maxBytes: Int) {
        self.directory = directory
        self.maxBytes = maxBytes
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    /// Returns cached bytes for `url` if present, else `nil`. On a hit, touches the file's
    /// modification date so eviction is access-ordered (LRU-ish, oldest-accessed first).
    func cachedData(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard let data = try? Data(contentsOf: file) else { return nil }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: file.path
        )
        return data
    }

    /// Writes bytes to disk then evicts oldest entries until back under the size limit.
    func store(data: Data, for url: URL) {
        try? data.write(to: fileURL(for: url))
        evict()
    }

    /// Removes every file in the cache directory.
    func clear() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: Private

    /// Derives a stable, collision-free filename by hashing the absolute URL string.
    /// `lastPathComponent` is unsafe here — many CoinGecko image URLs end in `large.png`.
    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }

    /// NFR8: enforce a maximum on-disk size, deleting oldest-first until under the limit.
    private func evict() {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys)
        ) else { return }

        var entries: [CacheEntry] = []
        var total = 0
        for file in files {
            guard let values = try? file.resourceValues(forKeys: keys),
                  let size = values.fileSize else { continue }
            let date = values.contentModificationDate ?? .distantPast
            entries.append(CacheEntry(url: file, size: size, modified: date))
            total += size
        }

        guard total > maxBytes else { return }
        for entry in entries.sorted(by: { $0.modified < $1.modified }) {
            if total <= maxBytes { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private struct CacheEntry {
        let url: URL
        let size: Int
        let modified: Date
    }
}

// MARK: - @Dependency Registration

extension ImageCacheClient: DependencyKey {
    static let coinImagesSubdirectory = "coin_images"
    /// NFR8 — 50 MB is generous for ~250 coin icons yet bounded; documented, not arbitrary.
    static let maxCacheBytes = 50 * 1024 * 1024

    nonisolated(unsafe) static var liveValue: ImageCacheClient = .live(
        cacheDirectory: FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(coinImagesSubdirectory),
        maxBytes: maxCacheBytes
    )

    /// Deterministic stub — any test touching `\.imageCache` must override it explicitly
    /// (BaseSuite registers no default). Cache/eviction tests use `.live(cacheDirectory:)` directly.
    nonisolated(unsafe) static var testValue: ImageCacheClient = ImageCacheClient(
        image: { _ in UIImage() },
        clearCache: {}
    )

    /// Placeholder so SwiftUI previews render without any I/O.
    nonisolated(unsafe) static var previewValue: ImageCacheClient = ImageCacheClient(
        image: { _ in UIImage(systemName: "photo") ?? UIImage() },
        clearCache: {}
    )
}

extension DependencyValues {
    var imageCache: ImageCacheClient {
        get { self[ImageCacheClient.self] }
        set { self[ImageCacheClient.self] = newValue }
    }
}

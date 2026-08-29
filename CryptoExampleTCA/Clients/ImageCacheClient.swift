import CryptoKit
import Dependencies
import Foundation
import ImageIO
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
                // `imageHTTPClient` — NOT `httpClient` — is resolved at call time. It is a separate
                // registration precisely so the CoinGecko API key injected into `\.httpClient` at
                // launch never reaches the image CDN, or whatever host an untrusted `CoinModel.image`
                // names. Tests override it via `withDependencies { $0.imageHTTPClient = ... }`. The
                // disk-hit check and request coalescing live inside the actor (see `data(for:fetch:)`).
                @Dependency(\.imageHTTPClient) var imageHTTPClient
                let data = try await cache.data(for: url) {
                    try await imageHTTPClient.execute(URLRequest(url: url)) // AC3
                }
                // The actor only returns bytes it has already validated as decodable, so a `nil`
                // here means the downsampling decode itself failed.
                guard let image = downsampledImage(from: data) else {
                    throw ImageCacheError.decodingFailed // AC5
                }
                return image
            },
            clearCache: { await cache.clear() }
        )
    }

    /// Coin icons arrive from CoinGecko at ~200×200 but render in a 30pt slot. Decoding at full
    /// size parks ~160 KB of RGBA per coin in `HomeFeature.State.images`, which is never evicted —
    /// ~40 MB across 250 coins. Decoding through a thumbnail caps every entry at
    /// `maxIconPixelSize` instead. The 50 MB `maxBytes` limit bounds *disk* bytes only; this is the
    /// in-memory counterpart.
    static let maxIconPixelSize = 120 // 30pt slot at 3× is 90px; 120 leaves headroom.

    /// Decodes `data` at no more than `maxIconPixelSize` on its longest edge. Images already at or
    /// below that size pass through unscaled. Falls back to a full-size decode if the source cannot
    /// produce a thumbnail, so a valid-but-unusual image is still displayed rather than dropped.
    private static func downsampledImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxIconPixelSize
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: thumbnail)
    }
}

// MARK: - Disk Cache Engine

/// Owns all `FileManager` I/O for the image cache plus in-flight request coalescing. Stores and
/// returns `Data` only — decoding to the non-`Sendable` `UIImage` happens in the `image` closure,
/// keeping the actor boundary clean under Swift 6 strict concurrency.
private actor ImageDiskCache {
    let directory: URL
    let maxBytes: Int

    /// Loads in progress, keyed by URL, so concurrent requests for the same URL share one network
    /// fetch instead of each hitting the network and each writing the same file.
    private var inFlight: [URL: Task<Data, Error>] = [:]

    init(directory: URL, maxBytes: Int) {
        self.directory = directory
        self.maxBytes = maxBytes
        // Inlined rather than calling `ensureDirectoryExists()`: an actor's synchronous init runs in
        // a nonisolated context and cannot call isolated instance methods.
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    /// Returns the bytes for `url`, in priority order: on-disk cache hit (no network), an already
    /// in-flight fetch for the same URL (coalesced), or a fresh fetch via `fetch`. A fresh fetch is
    /// validated as decodable before it is written, so undecodable bytes throw and store nothing.
    func data(for url: URL, fetch: @Sendable @escaping () async throws -> Data) async throws -> Data {
        // AC2: disk hit → return without any network request. Bytes that no longer decode (a
        // truncated/corrupt file, e.g. from a mid-write kill) are treated as a miss so the fetch
        // path below refetches and overwrites them — the cache self-heals.
        if let cached = cachedData(for: url), UIImage(data: cached) != nil {
            return cached
        }
        // Coalesce concurrent requests for the same uncached URL onto a single fetch.
        if let existing = inFlight[url] {
            return try await existing.value
        }
        let task = Task<Data, Error> {
            let data = try await fetch()
            guard UIImage(data: data) != nil else {
                throw ImageCacheError.decodingFailed // AC5: decode fails → nothing written
            }
            store(data: data, for: url) // AC3 write + AC4 eviction
            return data
        }
        inFlight[url] = task
        // A subsequent request for the same URL either finds this task above, or (once it completes)
        // finds the bytes on disk via `cachedData`, so clearing the slot here cannot orphan a fetch.
        defer { inFlight[url] = nil }
        return try await task.value
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

    /// Returns cached bytes for `url` if present, else `nil`. On a hit, touches the file's
    /// modification date so eviction is access-ordered (LRU-ish, oldest-accessed first).
    private func cachedData(for url: URL) -> Data? {
        let file = fileURL(for: url)
        guard let data = try? Data(contentsOf: file) else { return nil }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: file.path
        )
        return data
    }

    /// Writes bytes to disk then evicts oldest entries until back under the size limit. The
    /// just-written entry is protected from eviction so a fresh fetch is never immediately deleted
    /// (matters when a single item is larger than `maxBytes`).
    private func store(data: Data, for url: URL) {
        ensureDirectoryExists() // the OS can purge `.cachesDirectory` between writes
        let file = fileURL(for: url)
        try? data.write(to: file)
        evict(protecting: file)
    }

    /// Creates the cache directory if it does not currently exist. Cheap and idempotent; called
    /// before every write because iOS may reclaim `.cachesDirectory` at any time.
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    /// Derives a stable, collision-free filename by hashing the absolute URL string.
    /// `lastPathComponent` is unsafe here — many CoinGecko image URLs end in `large.png`.
    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }

    /// NFR8: enforce a maximum on-disk size, deleting oldest-first until under the limit. `protected`
    /// is never deleted (the entry just written by `store`).
    private func evict(protecting protected: URL? = nil) {
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
        let candidates = entries
            .filter { $0.url != protected }
            .sorted { lhs, rhs in
                // Oldest-first; break ties on the filename so eviction order is deterministic even
                // when two files share a (coarse-granularity) modification date.
                lhs.modified == rhs.modified
                    ? lhs.url.absoluteString < rhs.url.absoluteString
                    : lhs.modified < rhs.modified
            }
        for entry in candidates {
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

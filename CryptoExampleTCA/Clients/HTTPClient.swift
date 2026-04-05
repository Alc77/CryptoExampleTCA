import Foundation
import Dependencies

struct HTTPClient {
    var execute: @Sendable (URLRequest) async throws -> Data
}

extension HTTPClient {
    /// Factory used by app entry point to inject the API key at launch.
    /// Never hardcode the key in source — always pass it from Bundle at runtime.
    static func live(apiKey: String) -> HTTPClient {
        HTTPClient { request in
            var request = request
            if !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CoinGeckoError.networkUnavailable
                }
                if httpResponse.statusCode == 429 {
                    throw CoinGeckoError.rateLimited
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw CoinGeckoError.badResponse(statusCode: httpResponse.statusCode)
                }
                return data
            } catch let coinGeckoError as CoinGeckoError {
                throw coinGeckoError
            } catch let error as CancellationError {
                throw error
            } catch {
                throw CoinGeckoError.networkUnavailable
            }
        }
    }
}

// MARK: - @Dependency Registration

extension HTTPClient: DependencyKey {
    /// Safe default — always overridden at app launch via withDependencies (Story 1.6).
    nonisolated(unsafe) static var liveValue: HTTPClient = .live(apiKey: "")
    /// No-throw stub — returns empty Data. Tests override execute directly.
    nonisolated(unsafe) static var testValue: HTTPClient = HTTPClient { _ in Data() }
    nonisolated(unsafe) static var previewValue: HTTPClient = HTTPClient { _ in Data() }
}

extension DependencyValues {
    var httpClient: HTTPClient {
        get { self[HTTPClient.self] }
        set { self[HTTPClient.self] = newValue }
    }
}

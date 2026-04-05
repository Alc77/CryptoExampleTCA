import Foundation
import Dependencies

struct CoinGeckoClient {
    var fetchCoins: @Sendable () async throws -> [CoinModel]
    var fetchMarketData: @Sendable () async throws -> MarketDataModel
    var fetchCoinDetail: @Sendable (String) async throws -> CoinDetailModel
}

// MARK: - Live Implementation

private let baseURL = "https://api.coingecko.com/api/v3"

extension CoinGeckoClient {
    static var live: CoinGeckoClient {
        CoinGeckoClient(
            fetchCoins: {
                @Dependency(\.httpClient) var httpClient
                var components = URLComponents(string: "\(baseURL)/coins/markets")!
                components.queryItems = [
                    URLQueryItem(name: "vs_currency", value: "usd"),
                    URLQueryItem(name: "order", value: "market_cap_desc"),
                    URLQueryItem(name: "per_page", value: "250"),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "sparkline", value: "true"),
                    URLQueryItem(name: "price_change_percentage", value: "24h"),
                ]
                guard let url = components.url else { throw CoinGeckoError.networkUnavailable }
                let data = try await httpClient.execute(URLRequest(url: url))
                do {
                    return try JSONDecoder().decode([CoinModel].self, from: data)
                } catch is DecodingError {
                    throw CoinGeckoError.decodingFailed
                }
            },
            fetchMarketData: {
                @Dependency(\.httpClient) var httpClient
                let url = URL(string: "\(baseURL)/global")!
                let data = try await httpClient.execute(URLRequest(url: url))
                do {
                    return try JSONDecoder().decode(MarketDataModel.self, from: data)
                } catch is DecodingError {
                    throw CoinGeckoError.decodingFailed
                }
            },
            fetchCoinDetail: { id in
                guard !id.isEmpty else { throw CoinGeckoError.networkUnavailable }
                @Dependency(\.httpClient) var httpClient
                guard let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    throw CoinGeckoError.networkUnavailable
                }
                var components = URLComponents(string: "\(baseURL)/coins/\(encodedId)")!
                components.queryItems = [
                    URLQueryItem(name: "localization", value: "false"),
                    URLQueryItem(name: "tickers", value: "false"),
                    URLQueryItem(name: "market_data", value: "true"),
                    URLQueryItem(name: "community_data", value: "false"),
                    URLQueryItem(name: "developer_data", value: "false"),
                    URLQueryItem(name: "sparkline", value: "true"),
                ]
                guard let url = components.url else { throw CoinGeckoError.networkUnavailable }
                let data = try await httpClient.execute(URLRequest(url: url))
                do {
                    return try JSONDecoder().decode(CoinDetailModel.self, from: data)
                } catch is DecodingError {
                    throw CoinGeckoError.decodingFailed
                }
            }
        )
    }
}

// MARK: - @Dependency Registration

extension CoinGeckoClient: DependencyKey {
    nonisolated(unsafe) static var liveValue: CoinGeckoClient = .live
    nonisolated(unsafe) static var testValue: CoinGeckoClient = CoinGeckoClient(
        fetchCoins: unimplemented("CoinGeckoClient.fetchCoins"),
        fetchMarketData: unimplemented("CoinGeckoClient.fetchMarketData"),
        fetchCoinDetail: unimplemented("CoinGeckoClient.fetchCoinDetail(_:)")
    )
    nonisolated(unsafe) static var previewValue: CoinGeckoClient = CoinGeckoClient(
        fetchCoins: { [] },
        fetchMarketData: {
            MarketDataModel(data: MarketDataModel.GlobalData(
                totalMarketCap: [:],
                totalVolume: [:],
                marketCapPercentage: [:],
                marketCapChangePercentage24HUsd: 0
            ))
        },
        fetchCoinDetail: { _ in throw CoinGeckoError.networkUnavailable }
    )
}

extension DependencyValues {
    var coinGeckoClient: CoinGeckoClient {
        get { self[CoinGeckoClient.self] }
        set { self[CoinGeckoClient.self] = newValue }
    }
}

import XCTest
import Dependencies
@testable import CryptoExampleTCA

final class CoinGeckoClientTests: XCTestCase {

    func testFetchCoinsDecodes() async throws {
        let json = Data("""
            [{"id":"bitcoin","symbol":"btc","name":"Bitcoin","image":"https://example.com/btc.png"}]
            """.utf8)
        let coins = try await withDependencies {
            $0.httpClient = HTTPClient { _ in json }
        } operation: {
            try await CoinGeckoClient.liveValue.fetchCoins()
        }
        XCTAssertEqual(coins.first?.id, "bitcoin")
    }

    func testFetchMarketDataDecodes() async throws {
        let json = Data("""
            {
              "data": {
                "total_market_cap": {"usd": 1000000000000},
                "total_volume": {"usd": 50000000000},
                "market_cap_percentage": {"btc": 50.0},
                "market_cap_change_percentage_24h_usd": 1.5
              }
            }
            """.utf8)
        let marketData = try await withDependencies {
            $0.httpClient = HTTPClient { _ in json }
        } operation: {
            try await CoinGeckoClient.liveValue.fetchMarketData()
        }
        XCTAssertNotNil(marketData.data.totalMarketCap["usd"])
    }

    func testFetchCoinDetailDecodes() async throws {
        let json = Data("""
            {
              "id": "bitcoin",
              "symbol": "btc",
              "name": "Bitcoin",
              "description": {"en": "Digital gold"},
              "links": {
                "homepage": ["https://bitcoin.org"],
                "subreddit_url": "https://reddit.com/r/bitcoin"
              },
              "image": {
                "thumb": "https://example.com/t.png",
                "small": "https://example.com/s.png",
                "large": "https://example.com/l.png"
              },
              "market_data": {
                "current_price": {"usd": 50000},
                "market_cap": {"usd": 1000000000},
                "total_volume": {"usd": 500000000},
                "high_24h": {"usd": 51000},
                "low_24h": {"usd": 49000},
                "ath": {"usd": 69000},
                "ath_change_percentage": {"usd": -27.5},
                "atl": {"usd": 67.81},
                "atl_change_percentage": {"usd": 73000}
              }
            }
            """.utf8)
        let detail = try await withDependencies {
            $0.httpClient = HTTPClient { _ in json }
        } operation: {
            try await CoinGeckoClient.liveValue.fetchCoinDetail("bitcoin")
        }
        XCTAssertEqual(detail.id, "bitcoin")
    }

    func testFetchMarketDataDecodingFailed() async throws {
        let json = Data("invalid".utf8)
        do {
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in json }
            } operation: {
                try await CoinGeckoClient.liveValue.fetchMarketData()
            }
            XCTFail("Expected CoinGeckoError.decodingFailed")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Expected CoinGeckoError, got \(error)")
        }
    }

    func testFetchCoinDetailDecodingFailed() async throws {
        let json = Data("invalid".utf8)
        do {
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in json }
            } operation: {
                try await CoinGeckoClient.liveValue.fetchCoinDetail("bitcoin")
            }
            XCTFail("Expected CoinGeckoError.decodingFailed")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Expected CoinGeckoError, got \(error)")
        }
    }

    func testDecodingFailedOnInvalidJSON() async throws {
        let json = Data("invalid".utf8)
        do {
            _ = try await withDependencies {
                $0.httpClient = HTTPClient { _ in json }
            } operation: {
                try await CoinGeckoClient.liveValue.fetchCoins()
            }
            XCTFail("Expected CoinGeckoError.decodingFailed")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Expected CoinGeckoError, got \(error)")
        }
    }
}

import Foundation
import Testing

extension BaseSuite {
    @Suite struct HTTPClientTests {

        @Test func successReturnsData() async throws {
            let expectedData = Data("{}".utf8)
            let client = HTTPClient { _ in expectedData }
            let url = try #require(URL(string: "https://example.com"))
            let request = URLRequest(url: url)
            let result = try await client.execute(request)
            #expect(result == expectedData)
        }

        @Test func badResponseThrowsCorrectError() async throws {
            let client = HTTPClient { _ in throw CoinGeckoError.badResponse(statusCode: 404) }
            let url = try #require(URL(string: "https://example.com"))
            let request = URLRequest(url: url)
            await #expect(throws: CoinGeckoError.badResponse(statusCode: 404)) {
                _ = try await client.execute(request)
            }
        }

        @Test func rateLimitedThrowsCorrectError() async throws {
            let client = HTTPClient { _ in throw CoinGeckoError.rateLimited }
            let url = try #require(URL(string: "https://example.com"))
            let request = URLRequest(url: url)
            await #expect(throws: CoinGeckoError.rateLimited) {
                _ = try await client.execute(request)
            }
        }

        @Test func networkUnavailableThrowsCorrectError() async throws {
            let client = HTTPClient { _ in throw CoinGeckoError.networkUnavailable }
            let url = try #require(URL(string: "https://example.com"))
            let request = URLRequest(url: url)
            await #expect(throws: CoinGeckoError.networkUnavailable) {
                _ = try await client.execute(request)
            }
        }
    }
}

import XCTest
@testable import CryptoExampleTCA

final class HTTPClientTests: XCTestCase {

    func testSuccessReturnsData() async throws {
        let expectedData = Data("{}".utf8)
        let client = HTTPClient { _ in expectedData }
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let request = URLRequest(url: url)
        let result = try await client.execute(request)
        XCTAssertEqual(result, expectedData)
    }

    func testBadResponseThrowsCorrectError() async throws {
        let client = HTTPClient { _ in throw CoinGeckoError.badResponse(statusCode: 404) }
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let request = URLRequest(url: url)
        do {
            _ = try await client.execute(request)
            XCTFail("Expected throw")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .badResponse(statusCode: 404))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRateLimitedThrowsCorrectError() async throws {
        let client = HTTPClient { _ in throw CoinGeckoError.rateLimited }
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let request = URLRequest(url: url)
        do {
            _ = try await client.execute(request)
            XCTFail("Expected throw")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNetworkUnavailableThrowsCorrectError() async throws {
        let client = HTTPClient { _ in throw CoinGeckoError.networkUnavailable }
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let request = URLRequest(url: url)
        do {
            _ = try await client.execute(request)
            XCTFail("Expected throw")
        } catch let error as CoinGeckoError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

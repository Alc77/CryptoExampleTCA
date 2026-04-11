import XCTest
@testable import CryptoExampleTCA

final class CoinGeckoErrorTests: XCTestCase {

    func testAllCasesProvideNonEmptyErrorDescription() {
        let cases: [CoinGeckoError] = [
            .networkUnavailable,
            .rateLimited,
            .decodingFailed,
            .badResponse(statusCode: 503)
        ]
        for error in cases {
            XCTAssertNotNil(
                error.errorDescription,
                "\(error) must have a localized description"
            )
            XCTAssertFalse(
                error.errorDescription?.isEmpty ?? true,
                "\(error) description is empty"
            )
        }
    }

    func testErrorDescriptionIsNotRawCaseName() {
        XCTAssertNotEqual(
            CoinGeckoError.networkUnavailable.errorDescription,
            "networkUnavailable"
        )
        XCTAssertNotEqual(
            CoinGeckoError.rateLimited.errorDescription,
            "rateLimited"
        )
        XCTAssertNotEqual(
            CoinGeckoError.decodingFailed.errorDescription,
            "decodingFailed"
        )
    }

    func testBadResponseIncludesStatusCode() {
        let description = CoinGeckoError.badResponse(statusCode: 503).errorDescription ?? ""
        XCTAssertTrue(
            description.contains("503"),
            "badResponse description must include the status code, got: \(description)"
        )
    }
}

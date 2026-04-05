import XCTest
@testable import CryptoExampleTCA

final class FormattingTests: XCTestCase {

    // MARK: - asCurrencyWith6Decimals

    func testCurrency6_verySmallValue() {
        // 0.000123 — digit sequence "000123" must appear regardless of decimal separator or currency symbol
        let result = 0.000123.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("000123"), "Expected 6 decimal digits for very small value, got: \(result)")
    }

    func testCurrency6_specRequiredSmallValue() {
        // 0.0000001 — spec-required edge case; at 6dp this rounds to 0.000000
        let result = 0.0000001.asCurrencyWith6Decimals()
        XCTAssertFalse(result.isEmpty, "Expected non-empty result for 0.0000001, got: \(result)")
    }

    func testCurrency6_exactOneCent() {
        // 0.001 — spec-required case; falls in 6dp tier (< 0.01)
        let result = 0.001.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("001000") || result.contains("0.001") || result.contains("0,001"),
                      "Expected 6 decimal digits for 0.001, got: \(result)")
    }

    func testCurrency6_smallValue() {
        // 0.001234 — digit sequence "001234" must appear regardless of locale
        let result = 0.001234.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("001234"), "Expected 6 decimal digits for sub-cent value, got: \(result)")
    }

    func testCurrency6_midValue() {
        let result = 1.50.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("1.50") || result.contains("1,50"), "Expected 2 decimals for value >= 1, got: \(result)")
    }

    func testCurrency6_largeValue() {
        let result = 1234.56.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("1") && result.contains("234"), "Expected formatted large value, got: \(result)")
    }

    func testCurrency6_veryLargeValue() {
        let result = 70000.0.asCurrencyWith6Decimals()
        XCTAssertTrue(result.contains("70"), "Expected value containing 70, got: \(result)")
    }

    func testCurrency6_returnsNonEmptyString() {
        XCTAssertFalse(42.0.asCurrencyWith6Decimals().isEmpty)
    }

    func testCurrency6_nan() {
        XCTAssertEqual(Double.nan.asCurrencyWith6Decimals(), "–", "NaN should return placeholder")
    }

    func testCurrency6_infinity() {
        XCTAssertEqual(Double.infinity.asCurrencyWith6Decimals(), "–", "Infinity should return placeholder")
    }

    func testCurrency6_negativeInfinity() {
        XCTAssertEqual((-Double.infinity).asCurrencyWith6Decimals(), "–", "Negative infinity should return placeholder")
    }

    // MARK: - asPercentString

    func testPercent_positive() {
        let result = 1.5.asPercentString()
        XCTAssertTrue(result.hasPrefix("+"), "Positive percent should start with '+', got: \(result)")
        XCTAssertTrue(result.contains("%"), "Percent string should contain '%', got: \(result)")
    }

    func testPercent_negative() {
        let result = (-1.5).asPercentString()
        XCTAssertTrue(result.hasPrefix("-"), "Negative percent should start with '-', got: \(result)")
        XCTAssertTrue(result.contains("%"), "Percent string should contain '%', got: \(result)")
    }

    func testPercent_zero() {
        let result = 0.0.asPercentString()
        XCTAssertTrue(result.contains("%"), "Zero percent should contain '%', got: \(result)")
        XCTAssertFalse(result.hasPrefix("+"), "Zero percent should not have '+' prefix, got: \(result)")
    }

    func testPercent_returnsNonEmptyString() {
        XCTAssertFalse(5.0.asPercentString().isEmpty)
    }

    func testPercent_nan() {
        XCTAssertEqual(Double.nan.asPercentString(), "–", "NaN should return placeholder")
    }

    func testPercent_infinity() {
        XCTAssertEqual(Double.infinity.asPercentString(), "–", "Infinity should return placeholder")
    }

    // MARK: - asBigNumber

    func testBigNumber_trillion() {
        let result = 1_500_000_000_000.0.asBigNumber()
        XCTAssertTrue(result.hasSuffix("T"), "Trillion should end with T, got: \(result)")
        XCTAssertTrue(result.contains("1"), "Value should contain 1, got: \(result)")
    }

    func testBigNumber_billion() {
        let result = 2_500_000_000.0.asBigNumber()
        XCTAssertTrue(result.hasSuffix("B"), "Billion should end with B, got: \(result)")
    }

    func testBigNumber_million() {
        let result = 3_500_000.0.asBigNumber()
        XCTAssertTrue(result.hasSuffix("M"), "Million should end with M, got: \(result)")
    }

    func testBigNumber_thousand() {
        let result = 4_500.0.asBigNumber()
        XCTAssertTrue(result.hasSuffix("K"), "Thousand should end with K, got: \(result)")
    }

    func testBigNumber_small() {
        let result = 123.0.asBigNumber()
        XCTAssertFalse(result.hasSuffix("K") || result.hasSuffix("M") || result.hasSuffix("B") || result.hasSuffix("T"),
                       "Small number should have no suffix, got: \(result)")
        XCTAssertTrue(result.contains("123"), "Small number should contain 123, got: \(result)")
    }

    func testBigNumber_negativeBillion() {
        let result = (-2_500_000_000.0).asBigNumber()
        XCTAssertTrue(result.hasPrefix("-"), "Negative big number should start with '-', got: \(result)")
        XCTAssertTrue(result.hasSuffix("B"), "Negative billion should end with B, got: \(result)")
    }

    func testBigNumber_negativeThousand() {
        let result = (-1_000.0).asBigNumber()
        XCTAssertTrue(result.hasPrefix("-"), "Negative thousand should start with '-', got: \(result)")
        XCTAssertTrue(result.hasSuffix("K"), "Negative thousand should end with K, got: \(result)")
    }

    func testBigNumber_nan() {
        XCTAssertEqual(Double.nan.asBigNumber(), "–", "NaN should return placeholder")
    }

    func testBigNumber_infinity() {
        XCTAssertEqual(Double.infinity.asBigNumber(), "–", "Infinity should return placeholder")
    }

    // MARK: - removingHTMLTags

    func testRemoveHTMLTags_basicTag() {
        let input = "<p>Hello</p>"
        XCTAssertEqual(input.removingHTMLTags, "Hello")
    }

    func testRemoveHTMLTags_multipleTags() {
        let input = "<p>Bitcoin is <strong>digital gold</strong>.</p>"
        XCTAssertEqual(input.removingHTMLTags, "Bitcoin is digital gold.")
    }

    func testRemoveHTMLTags_coinGeckoSample() {
        let input = "<p>Ethereum is a <a href=\"https://ethereum.org\">decentralized platform</a>.</p>"
        let result = input.removingHTMLTags
        XCTAssertFalse(result.contains("<"), "Result should not contain '<', got: \(result)")
        XCTAssertFalse(result.contains(">"), "Result should not contain '>', got: \(result)")
        XCTAssertTrue(result.contains("Ethereum"), "Result should contain 'Ethereum', got: \(result)")
    }

    func testRemoveHTMLTags_noTags() {
        let input = "Plain text with no HTML."
        XCTAssertEqual(input.removingHTMLTags, input)
    }

    func testRemoveHTMLTags_empty() {
        XCTAssertEqual("".removingHTMLTags, "")
    }

    func testRemoveHTMLTags_scriptContentStripped() {
        let input = "<script>alert('x')</script>Hello"
        let result = input.removingHTMLTags
        XCTAssertFalse(result.contains("alert"), "Script content should be stripped, got: \(result)")
        XCTAssertTrue(result.contains("Hello"), "Text after script should remain, got: \(result)")
    }

    func testRemoveHTMLTags_styleContentStripped() {
        let input = "<style>body{color:red}</style>Hello"
        let result = input.removingHTMLTags
        XCTAssertFalse(result.contains("color"), "Style content should be stripped, got: \(result)")
        XCTAssertTrue(result.contains("Hello"), "Text after style should remain, got: \(result)")
    }

    func testRemoveHTMLTags_htmlCommentStripped() {
        let input = "<!-- hidden comment -->Visible"
        let result = input.removingHTMLTags
        XCTAssertFalse(result.contains("hidden"), "Comment content should be stripped, got: \(result)")
        XCTAssertTrue(result.contains("Visible"), "Text after comment should remain, got: \(result)")
    }

    // MARK: - Date(coinGeckoString:)

    func testDateParsing_validString() {
        let dateString = "2021-11-10T14:24:11.849Z"
        let date = Date(coinGeckoString: dateString)
        XCTAssertNotNil(date, "Should parse valid CoinGecko date string")
    }

    func testDateParsing_withoutFractionalSeconds() {
        // CoinGecko ath_date/atl_date fields sometimes omit fractional seconds
        let dateString = "2015-10-20T00:00:00Z"
        let date = Date(coinGeckoString: dateString)
        XCTAssertNotNil(date, "Should parse ISO 8601 string without fractional seconds")
    }

    func testDateParsing_invalidString() {
        let date = Date(coinGeckoString: "not-a-date")
        XCTAssertNil(date, "Should return nil for invalid date string")
    }

    func testDateParsing_emptyString() {
        let date = Date(coinGeckoString: "")
        XCTAssertNil(date, "Should return nil for empty string")
    }

    func testDateParsing_shortDateStringNotEmpty() {
        let dateString = "2021-11-10T14:24:11.849Z"
        guard let date = Date(coinGeckoString: dateString) else {
            XCTFail("Expected valid date")
            return
        }
        let shortString = date.shortDateString
        XCTAssertFalse(shortString.isEmpty, "shortDateString should not be empty")
    }

    func testDateParsing_anotherValidString() {
        let dateString = "2020-03-15T08:00:00.000Z"
        let date = Date(coinGeckoString: dateString)
        XCTAssertNotNil(date, "Should parse another valid CoinGecko date string")
    }
}

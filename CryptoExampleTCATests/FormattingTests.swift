import Foundation
import Testing

extension BaseSuite {
    @Suite struct FormattingTests {

        // MARK: - asCurrencyWith6Decimals

        @Test func currency6VerySmallValue() {
            // 0.000123 — digit sequence "000123" must appear regardless of decimal separator or currency symbol
            let result = 0.000123.asCurrencyWith6Decimals()
            #expect(result.contains("000123"), "Expected 6 decimal digits for very small value, got: \(result)")
        }

        @Test func currency6SpecRequiredSmallValue() {
            // 0.0000001 — spec-required edge case; at 6dp this rounds to 0.000000
            let result = 0.0000001.asCurrencyWith6Decimals()
            #expect(!result.isEmpty, "Expected non-empty result for 0.0000001, got: \(result)")
        }

        @Test func currency6ExactOneCent() {
            // 0.001 — spec-required case; falls in 6dp tier (< 0.01)
            let result = 0.001.asCurrencyWith6Decimals()
            #expect(result.contains("001000") || result.contains("0.001") || result.contains("0,001"),
                    "Expected 6 decimal digits for 0.001, got: \(result)")
        }

        @Test func currency6SmallValue() {
            // 0.001234 — digit sequence "001234" must appear regardless of locale
            let result = 0.001234.asCurrencyWith6Decimals()
            #expect(result.contains("001234"), "Expected 6 decimal digits for sub-cent value, got: \(result)")
        }

        @Test func currency6MidValue() {
            let result = 1.50.asCurrencyWith6Decimals()
            #expect(result.contains("1.50") || result.contains("1,50"), "Expected 2 decimals for value >= 1, got: \(result)")
        }

        @Test func currency6LargeValue() {
            let result = 1234.56.asCurrencyWith6Decimals()
            #expect(result.contains("1") && result.contains("234"), "Expected formatted large value, got: \(result)")
        }

        @Test func currency6VeryLargeValue() {
            let result = 70000.0.asCurrencyWith6Decimals()
            #expect(result.contains("70"), "Expected value containing 70, got: \(result)")
        }

        @Test func currency6ReturnsNonEmptyString() {
            #expect(!42.0.asCurrencyWith6Decimals().isEmpty)
        }

        @Test func currency6Nan() {
            #expect(Double.nan.asCurrencyWith6Decimals() == "–", "NaN should return placeholder")
        }

        @Test func currency6Infinity() {
            #expect(Double.infinity.asCurrencyWith6Decimals() == "–", "Infinity should return placeholder")
        }

        @Test func currency6NegativeInfinity() {
            #expect((-Double.infinity).asCurrencyWith6Decimals() == "–", "Negative infinity should return placeholder")
        }

        // MARK: - asPercentString

        @Test func percentPositive() {
            let result = 1.5.asPercentString()
            #expect(result.hasPrefix("+"), "Positive percent should start with '+', got: \(result)")
            #expect(result.contains("%"), "Percent string should contain '%', got: \(result)")
        }

        @Test func percentNegative() {
            let result = (-1.5).asPercentString()
            #expect(result.hasPrefix("-"), "Negative percent should start with '-', got: \(result)")
            #expect(result.contains("%"), "Percent string should contain '%', got: \(result)")
        }

        @Test func percentZero() {
            let result = 0.0.asPercentString()
            #expect(result.contains("%"), "Zero percent should contain '%', got: \(result)")
            #expect(!result.hasPrefix("+"), "Zero percent should not have '+' prefix, got: \(result)")
        }

        @Test func percentReturnsNonEmptyString() {
            #expect(!5.0.asPercentString().isEmpty)
        }

        @Test func percentNan() {
            #expect(Double.nan.asPercentString() == "–", "NaN should return placeholder")
        }

        @Test func percentInfinity() {
            #expect(Double.infinity.asPercentString() == "–", "Infinity should return placeholder")
        }

        // MARK: - asBigNumber

        @Test func bigNumberTrillion() {
            let result = 1_500_000_000_000.0.asBigNumber()
            #expect(result.hasSuffix("T"), "Trillion should end with T, got: \(result)")
            #expect(result.contains("1"), "Value should contain 1, got: \(result)")
        }

        @Test func bigNumberBillion() {
            let result = 2_500_000_000.0.asBigNumber()
            #expect(result.hasSuffix("B"), "Billion should end with B, got: \(result)")
        }

        @Test func bigNumberMillion() {
            let result = 3_500_000.0.asBigNumber()
            #expect(result.hasSuffix("M"), "Million should end with M, got: \(result)")
        }

        @Test func bigNumberThousand() {
            let result = 4_500.0.asBigNumber()
            #expect(result.hasSuffix("K"), "Thousand should end with K, got: \(result)")
        }

        @Test func bigNumberSmall() {
            let result = 123.0.asBigNumber()
            #expect(!(result.hasSuffix("K") || result.hasSuffix("M") || result.hasSuffix("B") || result.hasSuffix("T")),
                    "Small number should have no suffix, got: \(result)")
            #expect(result.contains("123"), "Small number should contain 123, got: \(result)")
        }

        @Test func bigNumberNegativeBillion() {
            let result = (-2_500_000_000.0).asBigNumber()
            #expect(result.hasPrefix("-"), "Negative big number should start with '-', got: \(result)")
            #expect(result.hasSuffix("B"), "Negative billion should end with B, got: \(result)")
        }

        @Test func bigNumberNegativeThousand() {
            let result = (-1_000.0).asBigNumber()
            #expect(result.hasPrefix("-"), "Negative thousand should start with '-', got: \(result)")
            #expect(result.hasSuffix("K"), "Negative thousand should end with K, got: \(result)")
        }

        @Test func bigNumberNan() {
            #expect(Double.nan.asBigNumber() == "–", "NaN should return placeholder")
        }

        @Test func bigNumberInfinity() {
            #expect(Double.infinity.asBigNumber() == "–", "Infinity should return placeholder")
        }

        // MARK: - removingHTMLTags

        @Test func removeHTMLTagsBasicTag() {
            #expect("<p>Hello</p>".removingHTMLTags == "Hello")
        }

        @Test func removeHTMLTagsMultipleTags() {
            let input = "<p>Bitcoin is <strong>digital gold</strong>.</p>"
            #expect(input.removingHTMLTags == "Bitcoin is digital gold.")
        }

        @Test func removeHTMLTagsCoinGeckoSample() {
            let input = "<p>Ethereum is a <a href=\"https://ethereum.org\">decentralized platform</a>.</p>"
            let result = input.removingHTMLTags
            #expect(!result.contains("<"), "Result should not contain '<', got: \(result)")
            #expect(!result.contains(">"), "Result should not contain '>', got: \(result)")
            #expect(result.contains("Ethereum"), "Result should contain 'Ethereum', got: \(result)")
        }

        @Test func removeHTMLTagsNoTags() {
            let input = "Plain text with no HTML."
            #expect(input.removingHTMLTags == input)
        }

        @Test func removeHTMLTagsEmpty() {
            #expect("".removingHTMLTags.isEmpty)
        }

        @Test func removeHTMLTagsScriptContentStripped() {
            let input = "<script>alert('x')</script>Hello"
            let result = input.removingHTMLTags
            #expect(!result.contains("alert"), "Script content should be stripped, got: \(result)")
            #expect(result.contains("Hello"), "Text after script should remain, got: \(result)")
        }

        @Test func removeHTMLTagsStyleContentStripped() {
            let input = "<style>body{color:red}</style>Hello"
            let result = input.removingHTMLTags
            #expect(!result.contains("color"), "Style content should be stripped, got: \(result)")
            #expect(result.contains("Hello"), "Text after style should remain, got: \(result)")
        }

        @Test func removeHTMLTagsHtmlCommentStripped() {
            let input = "<!-- hidden comment -->Visible"
            let result = input.removingHTMLTags
            #expect(!result.contains("hidden"), "Comment content should be stripped, got: \(result)")
            #expect(result.contains("Visible"), "Text after comment should remain, got: \(result)")
        }

        // MARK: - Date(coinGeckoString:)

        @Test func dateParsingValidString() {
            #expect(Date(coinGeckoString: "2021-11-10T14:24:11.849Z") != nil, "Should parse valid CoinGecko date string")
        }

        @Test func dateParsingWithoutFractionalSeconds() {
            // CoinGecko ath_date/atl_date fields sometimes omit fractional seconds
            #expect(Date(coinGeckoString: "2015-10-20T00:00:00Z") != nil, "Should parse ISO 8601 string without fractional seconds")
        }

        @Test func dateParsingInvalidString() {
            #expect(Date(coinGeckoString: "not-a-date") == nil, "Should return nil for invalid date string")
        }

        @Test func dateParsingEmptyString() {
            #expect(Date(coinGeckoString: "") == nil, "Should return nil for empty string")
        }

        @Test func dateParsingShortDateStringNotEmpty() throws {
            let date = try #require(Date(coinGeckoString: "2021-11-10T14:24:11.849Z"), "Expected valid date")
            #expect(!date.shortDateString.isEmpty, "shortDateString should not be empty")
        }

        @Test func dateParsingAnotherValidString() {
            #expect(Date(coinGeckoString: "2020-03-15T08:00:00.000Z") != nil, "Should parse another valid CoinGecko date string")
        }
    }
}

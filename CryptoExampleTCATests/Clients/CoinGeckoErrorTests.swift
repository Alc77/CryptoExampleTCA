import Testing

extension BaseSuite {
    @Suite struct CoinGeckoErrorTests {

        @Test func allCasesProvideNonEmptyErrorDescription() {
            let cases: [CoinGeckoError] = [
                .networkUnavailable,
                .rateLimited,
                .decodingFailed,
                .badResponse(statusCode: 503)
            ]
            for error in cases {
                #expect(error.errorDescription != nil, "\(error) must have a localized description")
                #expect(!(error.errorDescription?.isEmpty ?? true), "\(error) description is empty")
            }
        }

        @Test func errorDescriptionIsNotRawCaseName() {
            #expect(CoinGeckoError.networkUnavailable.errorDescription != "networkUnavailable")
            #expect(CoinGeckoError.rateLimited.errorDescription != "rateLimited")
            #expect(CoinGeckoError.decodingFailed.errorDescription != "decodingFailed")
        }

        @Test func badResponseCarriesStatusCode() {
            // NOTE: badResponse's user-facing text is built via String(localized:) → Bundle.main,
            // which a hostless test bundle does not populate, so the *resolved* description cannot
            // be asserted here. We assert the underlying contract instead: the status code is carried
            // on the error case (and participates in equality). See Story 4.7 Review Findings.
            guard case let .badResponse(statusCode) = CoinGeckoError.badResponse(statusCode: 503) else {
                Issue.record("Expected .badResponse case")
                return
            }
            #expect(statusCode == 503)
            #expect(CoinGeckoError.badResponse(statusCode: 404) != .badResponse(statusCode: 503))
        }
    }
}

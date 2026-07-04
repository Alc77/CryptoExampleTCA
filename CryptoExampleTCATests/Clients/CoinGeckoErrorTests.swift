import Testing

extension BaseSuite {
    @Suite struct CoinGeckoErrorTests {

        // In a hostless test bundle, String(localized:) resolves against Bundle.main (the xctest
        // runner, which carries no app strings), so errorDescription returns the raw key rather
        // than the resolved translation. These tests assert the contracts verifiable WITHOUT
        // Bundle.main resolution: every case has a non-empty, per-case-distinct description, and
        // none collapses to the raw `String(describing:)` case name. Resolved-copy coverage would
        // need a strings-carrying host or a Bundle-injection seam (see Story 4.7 Review Findings).
        private static let allCases: [CoinGeckoError] = [
            .networkUnavailable,
            .rateLimited,
            .decodingFailed,
            .badResponse(statusCode: 503)
        ]

        @Test func allCasesProvideNonEmptyDistinctErrorDescriptions() {
            let descriptions = Self.allCases.map(\.errorDescription)
            for (error, description) in zip(Self.allCases, descriptions) {
                #expect(description != nil, "\(error) must have a localized description")
                #expect(!(description?.isEmpty ?? true), "\(error) description is empty")
            }
            let resolved = descriptions.compactMap { $0 }
            #expect(Set(resolved).count == Self.allCases.count, "each case must have its own description")
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

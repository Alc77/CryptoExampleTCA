import ComposableArchitecture
import Foundation
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct SettingsFeatureTests {

        // MARK: - AC5/AC9: dismissButtonTapped runs the dismiss effect

        @Test func dismissButtonTappedDismissesSheet() async {
            let didDismiss = LockIsolated(false)

            let store = TestStore(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { didDismiss.setValue(true) }
            }

            await store.send(.dismissButtonTapped)
            await store.finish()

            #expect(didDismiss.value)
        }

        // MARK: - AC4: coinGeckoLinkTapped opens the CoinGecko website

        @Test func coinGeckoLinkTappedOpensCoinGeckoWebsite() async throws {
            let expectedURL = try #require(URL(string: "https://www.coingecko.com"))
            let captured = LockIsolated<[URL]>([])

            let store = TestStore(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.withValue { $0.append(url) } }
            }

            await store.send(.coinGeckoLinkTapped)
            await store.finish()

            #expect(captured.value == [expectedURL])
        }

        // MARK: - AC5: developerLinkTapped opens the developer profile

        @Test func developerLinkTappedOpensDeveloperProfile() async throws {
            let expectedURL = try #require(URL(string: "https://github.com/Alc77"))
            let captured = LockIsolated<[URL]>([])

            let store = TestStore(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.withValue { $0.append(url) } }
            }

            await store.send(.developerLinkTapped)
            await store.finish()

            #expect(captured.value == [expectedURL])
        }

        // MARK: - AC6: a nil link URL is a no-op, not a crash

        @Test func coinGeckoLinkTappedIsNoOpWhenURLIsNil() async {
            let captured = LockIsolated<[URL]>([])

            let store = TestStore(initialState: SettingsFeature.State(coinGeckoURL: nil)) {
                SettingsFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.withValue { $0.append(url) } }
            }

            await store.send(.coinGeckoLinkTapped)
            await store.finish()

            #expect(captured.value.isEmpty)
        }

        @Test func developerLinkTappedIsNoOpWhenURLIsNil() async {
            let captured = LockIsolated<[URL]>([])

            let store = TestStore(initialState: SettingsFeature.State(developerURL: nil)) {
                SettingsFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.withValue { $0.append(url) } }
            }

            await store.send(.developerLinkTapped)
            await store.finish()

            #expect(captured.value.isEmpty)
        }
    }
}

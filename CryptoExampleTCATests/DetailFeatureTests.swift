import ComposableArchitecture
import Foundation
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct DetailFeatureTests {

        @Test func onAppearFetchesCoinDetailSuccess() async {
            let mockDetail = Self.mockCoinDetail

            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            } withDependencies: {
                $0.coinGeckoClient.fetchCoinDetail = { _ in mockDetail }
            }

            await store.send(.onAppear) {
                $0.isLoading = true
            }

            await store.receive(\.coinDetailFetched.success) {
                $0.isLoading = false
                $0.coinDetail = mockDetail
            }
        }

        @Test func onAppearFetchFailureSetsError() async {
            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            } withDependencies: {
                $0.coinGeckoClient.fetchCoinDetail = { _ in
                    throw CoinGeckoError.networkUnavailable
                }
            }

            await store.send(.onAppear) {
                $0.isLoading = true
            }

            await store.receive(\.coinDetailFetched.failure) {
                $0.isLoading = false
                $0.error = .networkUnavailable
            }
        }

        @Test func retryAfterFailureClearsErrorAndRestartsFetch() async {
            let mockDetail = Self.mockCoinDetail

            let store = TestStore(
                initialState: DetailFeature.State(
                    coin: Self.mockCoin,
                    coinDetail: nil,
                    isLoading: false,
                    error: .networkUnavailable
                )
            ) {
                DetailFeature()
            } withDependencies: {
                $0.coinGeckoClient.fetchCoinDetail = { _ in mockDetail }
            }

            await store.send(.onAppear) {
                $0.isLoading = true
                $0.error = nil
            }

            await store.receive(\.coinDetailFetched.success) {
                $0.isLoading = false
                $0.coinDetail = mockDetail
            }
        }

        @Test func onAppearPassesCoinIdToFetchCoinDetail() async {
            let capturedId = LockIsolated<String?>(nil)
            let mockDetail = Self.mockCoinDetail

            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            } withDependencies: {
                $0.coinGeckoClient.fetchCoinDetail = { id in
                    capturedId.setValue(id)
                    return mockDetail
                }
            }

            await store.send(.onAppear) {
                $0.isLoading = true
            }

            await store.receive(\.coinDetailFetched.success) {
                $0.isLoading = false
                $0.coinDetail = mockDetail
            }

            #expect(capturedId.value == "bitcoin")
        }

        @Test func descriptionToggledFlipsShowFullDescription() async {
            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            }

            await store.send(.descriptionToggled) {
                $0.showFullDescription = true
            }

            await store.send(.descriptionToggled) {
                $0.showFullDescription = false
            }
        }

        @Test func websiteLinkTappedInvokesURLOpener() async {
            let expectedURL = URL(string: "https://bitcoin.org")!
            let captured = LockIsolated<URL?>(nil)

            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.setValue(url) }
            }

            await store.send(.websiteLinkTapped(expectedURL))
            await store.finish()

            #expect(captured.value == expectedURL)
        }

        @Test func redditLinkTappedInvokesURLOpener() async {
            let expectedURL = URL(string: "https://reddit.com/r/bitcoin")!
            let captured = LockIsolated<URL?>(nil)

            let store = TestStore(
                initialState: DetailFeature.State(coin: Self.mockCoin)
            ) {
                DetailFeature()
            } withDependencies: {
                $0.urlOpener.open = { url in captured.setValue(url) }
            }

            await store.send(.redditLinkTapped(expectedURL))
            await store.finish()

            #expect(captured.value == expectedURL)
        }
    }
}

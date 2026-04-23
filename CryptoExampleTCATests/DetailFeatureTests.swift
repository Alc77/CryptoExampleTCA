import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

@MainActor
final class DetailFeatureTests: XCTestCase {
    func testOnAppearFetchesCoinDetailSuccess() async {
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

    func testOnAppearFetchFailureSetsError() async {
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

    func testRetryAfterFailureClearsErrorAndRestartsFetch() async {
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

    func testOnAppearPassesCoinIdToFetchCoinDetail() async {
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

        XCTAssertEqual(capturedId.value, "bitcoin")
    }

    func testDescriptionToggledFlipsShowFullDescription() async {
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
}

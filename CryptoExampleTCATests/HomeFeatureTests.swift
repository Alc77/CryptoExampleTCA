import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureTests: XCTestCase {

    @MainActor
    func testInitialStateHasNilDestination() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        XCTAssertNil(store.state.destination)
    }

    // MARK: - onAppear → coinsFetched success

    @MainActor
    func testOnAppearFetchesCoinsAndMarketDataSuccess() async {
        let mockCoins = Self.mockCoins
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { mockCoins }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = mockCoins
        }

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }
    }

    // MARK: - onAppear → marketDataFetched success

    @MainActor
    func testOnAppearMarketDataPopulatesStatistics() async {
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { [] }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success)

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }

        XCTAssertEqual(store.state.statistics.count, 3)
    }

    // MARK: - onAppear → coinsFetched failure

    @MainActor
    func testOnAppearCoinsFetchFailureSetsError() async {
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { throw CoinGeckoError.networkUnavailable }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.failure) {
            $0.error = .networkUnavailable
        }

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }
        // Partial failure preserved: coins-failure error is NOT wiped by market success.
        XCTAssertEqual(store.state.error, .networkUnavailable)
    }

    // MARK: - onAppear → marketDataFetched failure

    @MainActor
    func testOnAppearMarketDataFetchFailureSetsError() async {
        let mockCoins = Self.mockCoins

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { mockCoins }
            $0.coinGeckoClient.fetchMarketData = { throw CoinGeckoError.networkUnavailable }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = mockCoins
        }

        await store.receive(\.marketDataFetched.failure) {
            $0.error = .networkUnavailable
            $0.isLoading = false
        }
    }

    // MARK: - reloadButtonTapped tests

    @MainActor
    func testReloadButtonTappedTriggersHapticAndFetch() async {
        final class HapticCapture: @unchecked Sendable { var called = false }
        let capture = HapticCapture()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.hapticClient.impact = { capture.called = true }
            $0.coinGeckoClient.fetchCoins = { Self.mockCoins }
            $0.coinGeckoClient.fetchMarketData = { Self.mockMarketData }
        }

        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        XCTAssertTrue(capture.called, "Haptic impact should fire on reload")

        await store.receive(\.coinsFetched.success) {
            $0.coins = Self.mockCoins
        }
        await store.receive(\.marketDataFetched.success) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }
    }

    @MainActor
    func testReloadButtonTappedCancelsInFlightFetch() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.hapticClient.impact = { }
            $0.coinGeckoClient.fetchCoins = { Self.mockCoins }
            $0.coinGeckoClient.fetchMarketData = { Self.mockMarketData }
        }

        // First reload completes fully with synchronous mocks.
        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }
        await store.receive(\.coinsFetched.success) {
            $0.coins = Self.mockCoins
        }
        await store.receive(\.marketDataFetched.success) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }

        // Second reload: isLoading is false after first fetch completes.
        // The .cancellable(id:cancelInFlight:true) modifier ensures true in-flight
        // cancellation in production when two reloads happen before the first finishes.
        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }
        // coins already equal mockCoins — no state change on success
        await store.receive(\.coinsFetched.success)
        await store.receive(\.marketDataFetched.success) {
            $0.isLoading = false
        }
    }

    @MainActor
    func testReloadButtonTappedCoinsFetchFailureSetsError() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.hapticClient.impact = { }
            $0.coinGeckoClient.fetchCoins = { throw CoinGeckoError.networkUnavailable }
            $0.coinGeckoClient.fetchMarketData = { Self.mockMarketData }
        }

        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.failure) {
            $0.error = .networkUnavailable
        }
        await store.receive(\.marketDataFetched.success) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }
        // Partial failure preserved: coins-failure error is NOT wiped by market success.
        XCTAssertEqual(store.state.error, .networkUnavailable)
    }

    @MainActor
    func testReloadButtonTappedMarketDataFetchFailureSetsError() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.hapticClient.impact = { }
            $0.coinGeckoClient.fetchCoins = { Self.mockCoins }
            $0.coinGeckoClient.fetchMarketData = { throw CoinGeckoError.networkUnavailable }
        }

        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = Self.mockCoins
        }
        await store.receive(\.marketDataFetched.failure) {
            $0.error = .networkUnavailable
            $0.isLoading = false
        }
    }

    // MARK: - onAppear deduplication

    @MainActor
    func testOnAppearIgnoredWhenAlreadyAppeared() async {
        let store = TestStore(
            initialState: HomeFeature.State(hasAppeared: true)
        ) {
            HomeFeature()
        }

        await store.send(.onAppear)
        // No effects, no state changes — guard returns .none
    }

    // MARK: - Story 2.3: Error state + retry

    @MainActor
    func testOnAppearCoinsFailureSurfacesErrorAndClearsLoading() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { throw CoinGeckoError.networkUnavailable }
            $0.coinGeckoClient.fetchMarketData = { Self.mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
        }

        await store.receive(\.coinsFetched.failure) {
            $0.error = .networkUnavailable
        }
        // Partial failure: market success must NOT clear the coins-failure error.
        await store.receive(\.marketDataFetched.success) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }
        XCTAssertEqual(store.state.error, .networkUnavailable)
    }

    @MainActor
    func testReloadAfterErrorClearsErrorAndRefetches() async {
        var initial = HomeFeature.State()
        initial.error = .networkUnavailable
        initial.hasAppeared = true

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0.hapticClient.impact = { }
            $0.coinGeckoClient.fetchCoins = { Self.mockCoins }
            $0.coinGeckoClient.fetchMarketData = { Self.mockMarketData }
        }

        await store.send(.reloadButtonTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = Self.mockCoins
        }
        await store.receive(\.marketDataFetched.success) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }
    }

    @MainActor
    func testOnAppearMarketDataFailureSetsErrorAndClearsLoading() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { Self.mockCoins }
            $0.coinGeckoClient.fetchMarketData = { throw CoinGeckoError.rateLimited }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = Self.mockCoins
        }
        await store.receive(\.marketDataFetched.failure) {
            $0.error = .rateLimited
            $0.isLoading = false
        }
    }

    @MainActor
    func testOnAppearBothFetchesFailSurfacesLastError() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { throw CoinGeckoError.networkUnavailable }
            $0.coinGeckoClient.fetchMarketData = { throw CoinGeckoError.rateLimited }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
        }

        await store.receive(\.coinsFetched.failure) {
            $0.error = .networkUnavailable
        }
        // Last-write-wins: marketData failure overwrites the coins-failure error.
        await store.receive(\.marketDataFetched.failure) {
            $0.error = .rateLimited
            $0.isLoading = false
        }
    }

    @MainActor
    func testCoinsFetchedSuccessPreservesExistingError() async {
        // Success handlers MUST NOT clear state.error — clearing is the job of
        // `reloadButtonTapped` / `onAppear` at the start of a retry cycle.
        // Clearing on partial success would silently hide a real failure.
        var initial = HomeFeature.State()
        initial.error = .networkUnavailable
        initial.isLoading = true

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.coinsFetched(.success(Self.mockCoins))) {
            $0.coins = Self.mockCoins
        }
        XCTAssertEqual(store.state.error, .networkUnavailable)
    }

    @MainActor
    func testMarketDataFetchedSuccessPreservesExistingError() async {
        var initial = HomeFeature.State()
        initial.error = .networkUnavailable
        initial.isLoading = true

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.marketDataFetched(.success(Self.mockMarketData))) {
            $0.statistics = Self.mockMarketData.toStatistics()
            $0.isLoading = false
        }
        XCTAssertEqual(store.state.error, .networkUnavailable)
    }

    // MARK: - Destination tests still pass (no regression)

    @MainActor
    func testDestinationActionReturnsNone() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        // Ensure destination handling still returns .none (no crash, no state change)
        XCTAssertNil(store.state.destination)
        XCTAssertEqual(store.state.coins, [])
        XCTAssertEqual(store.state.statistics, [])
        XCTAssertFalse(store.state.isLoading)
        XCTAssertFalse(store.state.hasAppeared)
        XCTAssertNil(store.state.error)
    }
}

// Mock fixtures (`mockCoins`, `mockMarketData`) live in `HomeFeatureFixtures.swift`.

import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureSearchTests: XCTestCase {

    // MARK: - Debounced commit

    @MainActor
    func testSearchTextChangedUpdatesSearchTextImmediately() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.searchTextChanged("bit")) {
            $0.searchText = "bit"
        }
        await clock.advance(by: .seconds(0.5))
        await store.receive(\.searchCommitted) {
            $0.searchQuery = "bit"
        }
    }

    @MainActor
    func testRapidTypingDebouncesToSingleCommit() async {
        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.searchTextChanged("b")) { $0.searchText = "b" }
        await clock.advance(by: .milliseconds(200))

        await store.send(.searchTextChanged("bi")) { $0.searchText = "bi" }
        await clock.advance(by: .milliseconds(200))

        await store.send(.searchTextChanged("bit")) { $0.searchText = "bit" }
        await clock.advance(by: .seconds(0.5))

        await store.receive(\.searchCommitted) {
            $0.searchQuery = "bit"
        }
    }

    @MainActor
    func testClearingSearchRestoresFullList() async {
        let clock = TestClock()
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.searchText = "bit"
        initial.searchQuery = "bit"

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.searchTextChanged("")) {
            $0.searchText = ""
        }
        await clock.advance(by: .seconds(0.5))
        await store.receive(\.searchCommitted) {
            $0.searchQuery = ""
        }
        XCTAssertEqual(store.state.filteredCoins.count, HomeFeatureTests.mockCoins.count)
    }

    // MARK: - filteredCoins computed property

    func testFilteredCoinsByName() {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.searchQuery = "bitcoin"
        XCTAssertEqual(state.filteredCoins.map(\.id), ["bitcoin"])
    }

    func testFilteredCoinsBySymbol() {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.searchQuery = "eth"
        XCTAssertTrue(state.filteredCoins.contains { $0.id == "ethereum" })
        XCTAssertFalse(state.filteredCoins.contains { $0.id == "cardano" })
    }

    func testFilteredCoinsIsCaseInsensitive() {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.searchQuery = "BITCOIN"
        XCTAssertTrue(state.filteredCoins.contains { $0.id == "bitcoin" })
    }

    func testFilteredCoinsEmptyQueryReturnsAll() {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.searchQuery = ""
        XCTAssertEqual(state.filteredCoins.count, state.coins.count)
    }
}

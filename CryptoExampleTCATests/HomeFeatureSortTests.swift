import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureSortTests: XCTestCase {

    // MARK: - 5.9 Default state

    func testSortDefaultIsRankAscending() {
        let state = HomeFeature.State()
        XCTAssertEqual(state.sortOption, .rank)
        XCTAssertTrue(state.sortAscending)
    }

    // MARK: - 5.2 Rank ascending

    func testSortByRankAscending() {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        // Default state: sortOption = .rank, sortAscending = true
        XCTAssertEqual(state.filteredCoins.map(\.id), ["bitcoin", "ethereum", "cardano"])
    }

    // MARK: - 5.3 Rank descending (toggle)

    @MainActor
    func testSortByRankDescending() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }
        // From default rank-ascending, toggling rank → descending
        await store.send(.sortOptionSelected(.rank)) {
            $0.sortAscending = false
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["cardano", "ethereum", "bitcoin"])
    }

    // MARK: - 5.4 Price descending (default for price)

    @MainActor
    func testSortByPriceDescending() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }
        // Switching from rank to price → price defaults descending
        await store.send(.sortOptionSelected(.price)) {
            $0.sortOption = .price
            $0.sortAscending = false
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin", "ethereum", "cardano"])
    }

    // MARK: - 5.5 Price ascending (toggle)

    @MainActor
    func testSortByPriceAscending() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.sortOption = .price
        initial.sortAscending = false
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }
        // From price descending, toggle to price ascending
        await store.send(.sortOptionSelected(.price)) {
            $0.sortAscending = true
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["cardano", "ethereum", "bitcoin"])
    }

    // MARK: - 5.6 Holdings descending (default for holdings)

    @MainActor
    func testSortByHoldingsDescending() async {
        var bitcoinWithHoldings = HomeFeatureTests.mockCoins[0]  // Bitcoin $65000
        bitcoinWithHoldings.currentHoldings = 0.5  // value = 32500
        var ethWithHoldings = HomeFeatureTests.mockCoins[1]  // Ethereum $3500
        ethWithHoldings.currentHoldings = 2.0  // value = 7000
        // Cardano: currentHoldings = nil → value = 0

        var initial = HomeFeature.State()
        initial.coins = [HomeFeatureTests.mockCoins[2], ethWithHoldings, bitcoinWithHoldings]
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.sortOptionSelected(.holdings)) {
            $0.sortOption = .holdings
            $0.sortAscending = false
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin", "ethereum", "cardano"])
    }

    // MARK: - 5.7 Holdings ascending (toggle)

    @MainActor
    func testSortByHoldingsAscending() async {
        var bitcoinWithHoldings = HomeFeatureTests.mockCoins[0]
        bitcoinWithHoldings.currentHoldings = 0.5  // value = 32500
        var ethWithHoldings = HomeFeatureTests.mockCoins[1]
        ethWithHoldings.currentHoldings = 2.0  // value = 7000

        var initial = HomeFeature.State()
        initial.coins = [bitcoinWithHoldings, ethWithHoldings, HomeFeatureTests.mockCoins[2]]
        initial.sortOption = .holdings
        initial.sortAscending = false
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        // From holdings descending, toggle to holdings ascending
        await store.send(.sortOptionSelected(.holdings)) {
            $0.sortAscending = true
        }
        // Ascending: Cardano (0) first, Ethereum (7000) second, Bitcoin (32500) last
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["cardano", "ethereum", "bitcoin"])
    }

    // MARK: - 5.8 Combined search + sort

    @MainActor
    func testSortCombinedWithSearch() async {
        // "r" matches Ethereum (name "ethereum" contains 'r') and Cardano (name "cardano" contains 'r')
        // Bitcoin (name "bitcoin", symbol "btc") does not contain 'r'
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.searchQuery = "r"
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.sortOptionSelected(.price)) {
            $0.sortOption = .price
            $0.sortAscending = false
        }
        // Filtered to [ethereum, cardano]; price descending: $3500 > $0.45
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["ethereum", "cardano"])
    }

    // MARK: - 5.10 Switching option resets direction

    @MainActor
    func testSwitchingSortOptionResetsDirection() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.sortOption = .price
        initial.sortAscending = false
        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        // Switch from price to rank → rank defaults ascending
        await store.send(.sortOptionSelected(.rank)) {
            $0.sortOption = .rank
            $0.sortAscending = true
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin", "ethereum", "cardano"])
    }
}

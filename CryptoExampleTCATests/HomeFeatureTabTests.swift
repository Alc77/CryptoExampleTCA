import ComposableArchitecture
import Dependencies
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureTabTests: XCTestCase {

    // Per-test isolation for @Shared(.portfolioItems). HomeFeature.State() subscribes
    // @Shared at construction time, so the Realm and PersistentReferences cache must be
    // scoped per test — otherwise state leaks across tests in the same process.
    override func invokeTest() {
        withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            super.invokeTest()
        }
    }

    // MARK: - 5.2 Default tab is Live Prices

    func testDefaultTabIsLivePrices() {
        let state = HomeFeature.State()
        XCTAssertEqual(state.selectedTab, .livePrices)
    }

    // MARK: - 5.3 Portfolio tab shows only held coins

    @MainActor
    func testSwitchToPortfolioTabShowsOnlyHeldCoins() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)] }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.portfolio)) {
            $0.selectedTab = .portfolio
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin"])
    }

    // MARK: - 5.4 Portfolio tab empty holdings

    @MainActor
    func testSwitchToPortfolioTabEmptyHoldings() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.$portfolioItems.withLock { $0 = [] }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.portfolio)) {
            $0.selectedTab = .portfolio
        }
        XCTAssertTrue(store.state.filteredCoins.isEmpty)
    }

    // MARK: - 5.5 Switch back to Live Prices shows all coins

    @MainActor
    func testSwitchBackToLivePricesShowsAllCoins() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.selectedTab = .portfolio
        initial.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)] }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.livePrices)) {
            $0.selectedTab = .livePrices
        }
        XCTAssertEqual(store.state.filteredCoins.count, HomeFeatureTests.mockCoins.count)
    }

    // MARK: - 5.6 Portfolio tab with search filter

    @MainActor
    func testPortfolioTabWithSearchFilter() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.searchQuery = "bit"
        initial.$portfolioItems.withLock {
            $0 = [
                PortfolioItem(coinID: "bitcoin", amount: 0.5),
                PortfolioItem(coinID: "ethereum", amount: 1.0)
            ]
        }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.portfolio)) {
            $0.selectedTab = .portfolio
        }
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin"])
    }

    // MARK: - 5.7 Portfolio tab with price sorting

    @MainActor
    func testPortfolioTabWithPriceSortAscending() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.selectedTab = .portfolio
        initial.$portfolioItems.withLock {
            $0 = [
                PortfolioItem(coinID: "bitcoin", amount: 0.5),
                PortfolioItem(coinID: "ethereum", amount: 1.0)
            ]
        }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        // Switch to price (defaults to descending)
        await store.send(.sortOptionSelected(.price)) {
            $0.sortOption = .price
            $0.sortAscending = false
        }
        // Price descending: Bitcoin ($65000) > Ethereum ($3500)
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin", "ethereum"])

        // Toggle to ascending — order must flip
        await store.send(.sortOptionSelected(.price)) {
            $0.sortAscending = true
        }
        // Price ascending: Ethereum ($3500) < Bitcoin ($65000)
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["ethereum", "bitcoin"])
    }

    // MARK: - 5.7b Portfolio tab with holdings sorting

    @MainActor
    func testPortfolioTabWithHoldingsSorting() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.selectedTab = .portfolio
        // Bitcoin: 0.5 × $65000 = $32500, Ethereum: 1.0 × $3500 = $3500
        initial.$portfolioItems.withLock {
            $0 = [
                PortfolioItem(coinID: "bitcoin", amount: 0.5),
                PortfolioItem(coinID: "ethereum", amount: 1.0)
            ]
        }

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        // Switch to holdings sort (defaults to descending)
        await store.send(.sortOptionSelected(.holdings)) {
            $0.sortOption = .holdings
            $0.sortAscending = false
        }
        // Holdings value descending: Bitcoin ($32500) > Ethereum ($3500)
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["bitcoin", "ethereum"])

        // Toggle to ascending — order must flip
        await store.send(.sortOptionSelected(.holdings)) {
            $0.sortAscending = true
        }
        // Holdings value ascending: Ethereum ($3500) < Bitcoin ($32500)
        XCTAssertEqual(store.state.filteredCoins.map(\.id), ["ethereum", "bitcoin"])
    }

    // MARK: - 5.8 Tab switch preserves search and sort state

    @MainActor
    func testTabSwitchPreservesSearchAndSort() async {
        var initial = HomeFeature.State()
        initial.coins = HomeFeatureTests.mockCoins
        initial.searchQuery = "bit"
        initial.sortOption = .price
        initial.sortAscending = false

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.portfolio)) {
            $0.selectedTab = .portfolio
        }
        XCTAssertEqual(store.state.searchQuery, "bit")
        XCTAssertEqual(store.state.sortOption, .price)
        XCTAssertFalse(store.state.sortAscending)

        await store.send(.tabSelected(.livePrices)) {
            $0.selectedTab = .livePrices
        }
        XCTAssertEqual(store.state.searchQuery, "bit")
        XCTAssertEqual(store.state.sortOption, .price)
        XCTAssertFalse(store.state.sortAscending)
    }
}

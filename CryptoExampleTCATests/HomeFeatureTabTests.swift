import ComposableArchitecture
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct HomeFeatureTabTests {

        // MARK: - 5.2 Default tab is Live Prices

        @Test func defaultTabIsLivePrices() {
            let state = HomeFeature.State()
            #expect(state.selectedTab == .livePrices)
        }

        // MARK: - 5.3 Portfolio tab shows only held coins

        @Test func switchToPortfolioTabShowsOnlyHeldCoins() async {
            var initial = HomeFeature.State()
            initial.coins = HomeFeatureTests.mockCoins
            initial.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)] }

            let store = TestStore(initialState: initial) {
                HomeFeature()
            }

            await store.send(.tabSelected(.portfolio)) {
                $0.selectedTab = .portfolio
            }
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin"])
        }

        // MARK: - 5.4 Portfolio tab empty holdings

        @Test func switchToPortfolioTabEmptyHoldings() async {
            var initial = HomeFeature.State()
            initial.coins = HomeFeatureTests.mockCoins
            initial.$portfolioItems.withLock { $0 = [] }

            let store = TestStore(initialState: initial) {
                HomeFeature()
            }

            await store.send(.tabSelected(.portfolio)) {
                $0.selectedTab = .portfolio
            }
            #expect(store.state.filteredCoins.isEmpty)
        }

        // MARK: - 5.5 Switch back to Live Prices shows all coins

        @Test func switchBackToLivePricesShowsAllCoins() async {
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
            #expect(store.state.filteredCoins.count == HomeFeatureTests.mockCoins.count)
        }

        // MARK: - 5.6 Portfolio tab with search filter

        @Test func portfolioTabWithSearchFilter() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin"])
        }

        // MARK: - 5.7 Portfolio tab with price sorting

        @Test func portfolioTabWithPriceSortAscending() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin", "ethereum"])

            // Toggle to ascending — order must flip
            await store.send(.sortOptionSelected(.price)) {
                $0.sortAscending = true
            }
            // Price ascending: Ethereum ($3500) < Bitcoin ($65000)
            #expect(store.state.filteredCoins.map(\.id) == ["ethereum", "bitcoin"])
        }

        // MARK: - 5.7b Portfolio tab with holdings sorting

        @Test func portfolioTabWithHoldingsSorting() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin", "ethereum"])

            // Toggle to ascending — order must flip
            await store.send(.sortOptionSelected(.holdings)) {
                $0.sortAscending = true
            }
            // Holdings value ascending: Ethereum ($3500) < Bitcoin ($32500)
            #expect(store.state.filteredCoins.map(\.id) == ["ethereum", "bitcoin"])
        }

        // MARK: - 5.8 Tab switch preserves search and sort state

        @Test func tabSwitchPreservesSearchAndSort() async {
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
            #expect(store.state.searchQuery == "bit")
            #expect(store.state.sortOption == .price)
            #expect(!store.state.sortAscending)

            await store.send(.tabSelected(.livePrices)) {
                $0.selectedTab = .livePrices
            }
            #expect(store.state.searchQuery == "bit")
            #expect(store.state.sortOption == .price)
            #expect(!store.state.sortAscending)
        }
    }
}

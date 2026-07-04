import ComposableArchitecture
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct HomeFeatureSortTests {

        // MARK: - 5.9 Default state

        @Test func sortDefaultIsRankAscending() {
            let state = HomeFeature.State()
            #expect(state.sortOption == .rank)
            #expect(state.sortAscending)
        }

        // MARK: - 5.2 Rank ascending

        @Test func sortByRankAscending() {
            var state = HomeFeature.State()
            state.coins = HomeFeatureTests.mockCoins
            // Default state: sortOption = .rank, sortAscending = true
            #expect(state.filteredCoins.map(\.id) == ["bitcoin", "ethereum", "cardano"])
        }

        // MARK: - 5.3 Rank descending (toggle)

        @Test func sortByRankDescending() async {
            var initial = HomeFeature.State()
            initial.coins = HomeFeatureTests.mockCoins
            let store = TestStore(initialState: initial) {
                HomeFeature()
            }
            // From default rank-ascending, toggling rank → descending
            await store.send(.sortOptionSelected(.rank)) {
                $0.sortAscending = false
            }
            #expect(store.state.filteredCoins.map(\.id) == ["cardano", "ethereum", "bitcoin"])
        }

        // MARK: - 5.4 Price descending (default for price)

        @Test func sortByPriceDescending() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin", "ethereum", "cardano"])
        }

        // MARK: - 5.5 Price ascending (toggle)

        @Test func sortByPriceAscending() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["cardano", "ethereum", "bitcoin"])
        }

        // MARK: - 5.6 Holdings descending (default for holdings)

        @Test func sortByHoldingsDescending() async {
            // Holdings overlay now comes from @Shared portfolioItems, not CoinModel.currentHoldings
            // Bitcoin: 0.5 × $65000 = $32500, Ethereum: 2.0 × $3500 = $7000, Cardano: nil → $0
            var initial = HomeFeature.State()
            initial.coins = [HomeFeatureTests.mockCoins[2], HomeFeatureTests.mockCoins[1], HomeFeatureTests.mockCoins[0]]
            initial.$portfolioItems.withLock {
                $0 = [
                    PortfolioItem(coinID: "bitcoin", amount: 0.5),
                    PortfolioItem(coinID: "ethereum", amount: 2.0)
                ]
            }
            let store = TestStore(initialState: initial) {
                HomeFeature()
            }

            await store.send(.sortOptionSelected(.holdings)) {
                $0.sortOption = .holdings
                $0.sortAscending = false
            }
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin", "ethereum", "cardano"])
        }

        // MARK: - 5.7 Holdings ascending (toggle)

        @Test func sortByHoldingsAscending() async {
            // Holdings overlay now comes from @Shared portfolioItems
            // Bitcoin: 0.5 × $65000 = $32500, Ethereum: 2.0 × $3500 = $7000, Cardano: nil → $0
            var initial = HomeFeature.State()
            initial.coins = [HomeFeatureTests.mockCoins[0], HomeFeatureTests.mockCoins[1], HomeFeatureTests.mockCoins[2]]
            initial.sortOption = .holdings
            initial.sortAscending = false
            initial.$portfolioItems.withLock {
                $0 = [
                    PortfolioItem(coinID: "bitcoin", amount: 0.5),
                    PortfolioItem(coinID: "ethereum", amount: 2.0)
                ]
            }
            let store = TestStore(initialState: initial) {
                HomeFeature()
            }

            // From holdings descending, toggle to holdings ascending
            await store.send(.sortOptionSelected(.holdings)) {
                $0.sortAscending = true
            }
            // Ascending: Cardano (0) first, Ethereum (7000) second, Bitcoin (32500) last
            #expect(store.state.filteredCoins.map(\.id) == ["cardano", "ethereum", "bitcoin"])
        }

        // MARK: - 5.8 Combined search + sort

        @Test func sortCombinedWithSearch() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["ethereum", "cardano"])
        }

        // MARK: - 5.10 Switching option resets direction

        @Test func switchingSortOptionResetsDirection() async {
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
            #expect(store.state.filteredCoins.map(\.id) == ["bitcoin", "ethereum", "cardano"])
        }
    }
}

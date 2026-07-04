import ComposableArchitecture
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct HomeFeatureSearchTests {

        // MARK: - Debounced commit

        @Test func searchTextChangedUpdatesSearchTextImmediately() async {
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

        @Test func rapidTypingDebouncesToSingleCommit() async {
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

        @Test func clearingSearchRestoresFullList() async {
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
            #expect(store.state.filteredCoins.count == HomeFeatureTests.mockCoins.count)
        }

        // MARK: - filteredCoins computed property

        @Test func filteredCoinsByName() {
            var state = HomeFeature.State()
            state.coins = HomeFeatureTests.mockCoins
            state.searchQuery = "bitcoin"
            #expect(state.filteredCoins.map(\.id) == ["bitcoin"])
        }

        @Test func filteredCoinsBySymbol() {
            var state = HomeFeature.State()
            state.coins = HomeFeatureTests.mockCoins
            state.searchQuery = "eth"
            #expect(state.filteredCoins.contains { $0.id == "ethereum" })
            #expect(!state.filteredCoins.contains { $0.id == "cardano" })
        }

        @Test func filteredCoinsIsCaseInsensitive() {
            var state = HomeFeature.State()
            state.coins = HomeFeatureTests.mockCoins
            state.searchQuery = "BITCOIN"
            #expect(state.filteredCoins.contains { $0.id == "bitcoin" })
        }

        @Test func filteredCoinsEmptyQueryReturnsAll() {
            var state = HomeFeature.State()
            state.coins = HomeFeatureTests.mockCoins
            state.searchQuery = ""
            #expect(state.filteredCoins.count == state.coins.count)
        }
    }
}

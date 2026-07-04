import ComposableArchitecture
import Foundation
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct PortfolioFeatureSearchTests {

        private let bitcoin = PortfolioFeatureTests.bitcoin
        private let ethereum = PortfolioFeatureTests.ethereum

        private func makeSearchStore(
            state: PortfolioFeature.State = .init(),
            clock: TestClock<Duration>? = nil
        ) -> TestStoreOf<PortfolioFeature> {
            TestStore(initialState: state) { PortfolioFeature() } withDependencies: {
                $0.realmController = .inMemory(id: UUID().uuidString)
                if let clock { $0.continuousClock = clock }
            }
        }

        @Test func searchTextChangedUpdatesSearchTextImmediately() async {
            let clock = TestClock()
            let store = makeSearchStore(clock: clock)
            await store.send(.searchTextChanged("bit")) { $0.searchText = "bit" }
            await clock.advance(by: .seconds(0.5))
            await store.receive(\.searchCommitted) { $0.searchQuery = "bit" }
        }

        @Test func rapidTypingDebouncesToSingleCommit() async {
            let clock = TestClock()
            let store = makeSearchStore(clock: clock)
            await store.send(.searchTextChanged("b")) { $0.searchText = "b" }
            await clock.advance(by: .milliseconds(200))
            await store.send(.searchTextChanged("bi")) { $0.searchText = "bi" }
            await clock.advance(by: .milliseconds(200))
            await store.send(.searchTextChanged("bit")) { $0.searchText = "bit" }
            await clock.advance(by: .seconds(0.5))
            await store.receive(\.searchCommitted) { $0.searchQuery = "bit" }
        }

        @Test func searchCommittedUpdatesSearchQuery() async {
            let store = makeSearchStore(state: .init(searchText: "eth"))
            await store.send(.searchCommitted) { $0.searchQuery = "eth" }
        }

        @Test func clearingSearchRestoresFullList() async {
            let clock = TestClock()
            let store = makeSearchStore(state: .init(coins: [bitcoin, ethereum], searchText: "bit", searchQuery: "bit"), clock: clock)
            await store.send(.searchTextChanged("")) { $0.searchText = "" }
            await clock.advance(by: .seconds(0.5))
            await store.receive(\.searchCommitted) { $0.searchQuery = "" }
        }

        @Test func filteredCoinsByName() {
            let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "bitcoin")
            #expect(state.filteredCoins.map(\.id) == ["bitcoin"])
        }

        @Test func filteredCoinsBySymbol() {
            let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "eth")
            #expect(state.filteredCoins.map(\.id) == ["ethereum"])
        }

        @Test func filteredCoinsIsCaseInsensitive() {
            let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "BITCOIN")
            #expect(state.filteredCoins.map(\.id) == ["bitcoin"])
        }

        @Test func filteredCoinsEmptyQueryReturnsAll() {
            let coins = [bitcoin, ethereum]
            #expect(PortfolioFeature.State(coins: coins).filteredCoins.map(\.id) == coins.map(\.id))
        }

        @Test func filteredCoinsNoMatchReturnsEmpty() {
            let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "xyznonexistent")
            #expect(state.filteredCoins.isEmpty)
        }

        @Test func filteredCoinsWhitespaceOnlyReturnsAll() {
            let coins = [bitcoin, ethereum]
            #expect(PortfolioFeature.State(coins: coins, searchQuery: "   ").filteredCoins.map(\.id) == coins.map(\.id))
        }

        @Test func searchCommittedClearsSelectedCoinAndAmount() async {
            let store = makeSearchStore(state: .init(selectedCoin: bitcoin, amountText: "5", searchText: "eth"))
            await store.send(.searchCommitted) {
                $0.searchQuery = "eth"
                $0.selectedCoin = nil
                $0.amountText = ""
            }
        }
    }
}

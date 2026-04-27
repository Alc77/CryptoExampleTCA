import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class PortfolioFeatureSearchTests: XCTestCase {

    private let bitcoin = PortfolioFeatureTests.bitcoin
    private let ethereum = PortfolioFeatureTests.ethereum

    @MainActor
    private func makeSearchStore(state: PortfolioFeature.State = .init(), clock: TestClock<Duration>? = nil) -> TestStoreOf<PortfolioFeature> {
        TestStore(initialState: state) { PortfolioFeature() } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
            if let clock { $0.continuousClock = clock }
        }
    }

    @MainActor func testSearchTextChangedUpdatesSearchTextImmediately() async {
        let clock = TestClock()
        let store = makeSearchStore(clock: clock)
        await store.send(.searchTextChanged("bit")) { $0.searchText = "bit" }
        await clock.advance(by: .seconds(0.5))
        await store.receive(\.searchCommitted) { $0.searchQuery = "bit" }
    }

    @MainActor func testRapidTypingDebouncesToSingleCommit() async {
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

    @MainActor func testSearchCommittedUpdatesSearchQuery() async {
        let store = makeSearchStore(state: .init(searchText: "eth"))
        await store.send(.searchCommitted) { $0.searchQuery = "eth" }
    }

    @MainActor func testClearingSearchRestoresFullList() async {
        let clock = TestClock()
        let store = makeSearchStore(state: .init(coins: [bitcoin, ethereum], searchText: "bit", searchQuery: "bit"), clock: clock)
        await store.send(.searchTextChanged("")) { $0.searchText = "" }
        await clock.advance(by: .seconds(0.5))
        await store.receive(\.searchCommitted) { $0.searchQuery = "" }
    }

    func testFilteredCoinsByName() {
        let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "bitcoin")
        XCTAssertEqual(state.filteredCoins.map(\.id), ["bitcoin"])
    }

    func testFilteredCoinsBySymbol() {
        let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "eth")
        XCTAssertEqual(state.filteredCoins.map(\.id), ["ethereum"])
    }

    func testFilteredCoinsIsCaseInsensitive() {
        let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "BITCOIN")
        XCTAssertEqual(state.filteredCoins.map(\.id), ["bitcoin"])
    }

    func testFilteredCoinsEmptyQueryReturnsAll() {
        let coins = [bitcoin, ethereum]
        XCTAssertEqual(PortfolioFeature.State(coins: coins).filteredCoins.map(\.id), coins.map(\.id))
    }

    func testFilteredCoinsNoMatchReturnsEmpty() {
        let state = PortfolioFeature.State(coins: [bitcoin, ethereum], searchQuery: "xyznonexistent")
        XCTAssertTrue(state.filteredCoins.isEmpty)
    }

    func testFilteredCoinsWhitespaceOnlyReturnsAll() {
        let coins = [bitcoin, ethereum]
        XCTAssertEqual(PortfolioFeature.State(coins: coins, searchQuery: "   ").filteredCoins.map(\.id), coins.map(\.id))
    }

    @MainActor func testSearchCommittedClearsSelectedCoinAndAmount() async {
        let store = makeSearchStore(state: .init(selectedCoin: bitcoin, amountText: "5", searchText: "eth"))
        await store.send(.searchCommitted) {
            $0.searchQuery = "eth"
            $0.selectedCoin = nil
            $0.amountText = ""
        }
    }
}

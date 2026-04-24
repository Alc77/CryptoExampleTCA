import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class PortfolioFeatureTests: XCTestCase {

    // MARK: - AC1: coinTapped selects coin and clears amount (new coin)

    @MainActor
    func testCoinTappedSelectsCoinAndClearsAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(coins: [bitcoin, ethereum])
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.coinTapped(bitcoin)) {
            $0.selectedCoin = bitcoin
            $0.amountText = ""
        }
    }

    // MARK: - AC1: coinTapped prefills existing holding

    @MainActor
    func testCoinTappedPrefillsExistingHolding() async {
        // Use a shared Realm id so the two stores observe the same @Shared(.portfolioItems) reference.
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            // Save store: seed portfolioItems with bitcoin 2.5. DismissEffect marks this store dismissed.
            let saveStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [bitcoin],
                    selectedCoin: bitcoin,
                    amountText: "2.5"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await saveStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 2.5)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await saveStore.finish()

            // Prefill store: portfolioItems is already [bitcoin 2.5] via the shared reference.
            let prefillStore = TestStore(
                initialState: PortfolioFeature.State(coins: [bitcoin])
            ) {
                PortfolioFeature()
            }
            await prefillStore.send(.coinTapped(bitcoin)) {
                $0.selectedCoin = bitcoin
                $0.amountText = "2.5"
            }
        }
    }

    // MARK: - amountChanged updates text

    @MainActor
    func testAmountChangedUpdatesText() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(coins: [bitcoin], selectedCoin: bitcoin)
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.amountChanged("2.5")) {
            $0.amountText = "2.5"
        }
    }

    // MARK: - AC2: saveButtonTapped appends new holding

    @MainActor
    func testSaveButtonTappedAddsNewHolding() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [bitcoin],
                selectedCoin: bitcoin,
                amountText: "2.5"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveButtonTapped) {
            $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 2.5)] }
            $0.amountText = ""
            $0.selectedCoin = nil
        }
        await store.finish()
    }

    // MARK: - AC3: saveButtonTapped updates existing holding (no duplicate)

    @MainActor
    func testSaveButtonTappedUpdatesExistingHolding() async {
        // Use a shared Realm id so both stores observe the same @Shared(.portfolioItems) reference.
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            // First save: add bitcoin at 1.0
            let firstStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [bitcoin],
                    selectedCoin: bitcoin,
                    amountText: "1.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await firstStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await firstStore.finish()

            // Second save: update bitcoin to 5.0 — shared reference already has [bitcoin 1.0].
            // Reducer must find the existing entry and update in-place; count must stay 1 (AC3).
            let updateStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [bitcoin],
                    selectedCoin: bitcoin,
                    amountText: "5.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await updateStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 5.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await updateStore.finish()
        }
    }

    // MARK: - AC4: saveButtonTapped no-ops on invalid amount

    @MainActor
    func testSaveButtonTappedNoOpsOnInvalidAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [bitcoin],
                selectedCoin: bitcoin,
                amountText: "abc"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }
}

// MARK: - Fixtures

private let bitcoin = CoinModel(
    id: "bitcoin",
    symbol: "btc",
    name: "Bitcoin",
    image: "https://example.com/btc.png",
    currentPrice: 65000.0,
    marketCap: 1_200_000_000_000,
    marketCapRank: 1,
    fullyDilutedValuation: 1_300_000_000_000,
    totalVolume: 30_000_000_000,
    high24H: 66000,
    low24H: 64000,
    priceChange24H: 1500,
    priceChangePercentage24H: 2.35,
    marketCapChange24H: 20_000_000_000,
    marketCapChangePercentage24H: 1.69,
    circulatingSupply: 19_500_000,
    totalSupply: 21_000_000,
    maxSupply: 21_000_000,
    ath: 73000,
    athChangePercentage: -10.96,
    athDate: "2024-03-14",
    atl: 67.81,
    atlChangePercentage: 95000,
    atlDate: "2013-07-06",
    lastUpdated: "2024-01-01T00:00:00.000Z",
    sparklineIn7D: nil,
    currentHoldings: nil
)

private let ethereum = CoinModel(
    id: "ethereum",
    symbol: "eth",
    name: "Ethereum",
    image: "https://example.com/eth.png",
    currentPrice: 3500.0,
    marketCap: 420_000_000_000,
    marketCapRank: 2,
    fullyDilutedValuation: 420_000_000_000,
    totalVolume: 15_000_000_000,
    high24H: 3600,
    low24H: 3400,
    priceChange24H: -50,
    priceChangePercentage24H: -1.41,
    marketCapChange24H: -5_000_000_000,
    marketCapChangePercentage24H: -1.18,
    circulatingSupply: 120_000_000,
    totalSupply: nil,
    maxSupply: nil,
    ath: 4878,
    athChangePercentage: -28.25,
    athDate: "2021-11-10",
    atl: 0.43,
    atlChangePercentage: 800000,
    atlDate: "2015-10-20",
    lastUpdated: "2024-01-01T00:00:00.000Z",
    sparklineIn7D: nil,
    currentHoldings: nil
)

import ComposableArchitecture
import Dependencies
import XCTest
@testable import CryptoExampleTCA

final class HomeFeaturePortfolioValuationTests: XCTestCase {

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

    // MARK: - AC3: empty portfolio produces zero value and no stats card

    func testPortfolioValueIsZeroWhenNoHoldings() {
        let state = HomeFeature.State()
        XCTAssertEqual(state.portfolioValue, 0)
        XCTAssertNil(state.portfolioStatistic)
    }

    // MARK: - AC3: persisted holdings with no coins loaded yet

    func testPortfolioValueIsZeroWhenCoinsListIsEmpty() {
        var state = HomeFeature.State()
        state.$portfolioItems.withLock {
            $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)]
        }
        XCTAssertEqual(state.portfolioValue, 0)
        XCTAssertNil(state.portfolioStatistic)
    }

    // MARK: - AC6: canonical portfolio value sum

    @MainActor
    func testPortfolioValueSumsPriceTimesAmount() async {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.$portfolioItems.withLock {
            $0 = [
                PortfolioItem(coinID: "bitcoin", amount: 0.5),
                PortfolioItem(coinID: "ethereum", amount: 1.0)
            ]
        }

        let store = TestStore(initialState: state) { HomeFeature() }

        // 0.5 × 65000 + 1.0 × 3500 = 32500 + 3500 = 36000
        let expected = 0.5 * 65000.0 + 1.0 * 3500.0
        XCTAssertEqual(store.state.portfolioValue, expected, accuracy: 1e-6)
        XCTAssertEqual(
            store.state.portfolioStatistic?.value,
            expected.asCurrencyWith2Decimals()
        )
        XCTAssertEqual(store.state.portfolioStatistic?.title, String(localized: "stats.portfolioValue"))
    }

    // MARK: - AC3: nil-price coin excluded from sum

    @MainActor
    func testPortfolioValueExcludesCoinsWithNilPrice() async {
        var state = HomeFeature.State()
        let bitcoinNoPrice = CoinModel(
            id: "bitcoin",
            symbol: "btc",
            name: "Bitcoin",
            image: "",
            currentPrice: nil,
            marketCap: nil, marketCapRank: nil, fullyDilutedValuation: nil, totalVolume: nil,
            high24H: nil, low24H: nil, priceChange24H: nil, priceChangePercentage24H: nil,
            marketCapChange24H: nil, marketCapChangePercentage24H: nil,
            circulatingSupply: nil, totalSupply: nil, maxSupply: nil,
            ath: nil, athChangePercentage: nil, athDate: nil,
            atl: nil, atlChangePercentage: nil, atlDate: nil,
            lastUpdated: nil, sparklineIn7D: nil, currentHoldings: nil
        )
        state.coins = [bitcoinNoPrice]
        state.$portfolioItems.withLock {
            $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)]
        }

        let store = TestStore(initialState: state) { HomeFeature() }

        XCTAssertEqual(store.state.portfolioValue, 0)
        XCTAssertNil(store.state.portfolioStatistic)
    }

    // MARK: - AC4: 24h portfolio change matches analytical formula

    @MainActor
    func testPortfolio24HChangeMatchesAnalyticalFormula() async {
        var state = HomeFeature.State()
        state.coins = HomeFeatureTests.mockCoins
        state.$portfolioItems.withLock {
            $0 = [
                PortfolioItem(coinID: "bitcoin", amount: 0.5),
                PortfolioItem(coinID: "ethereum", amount: 1.0)
            ]
        }

        let store = TestStore(initialState: state) { HomeFeature() }

        // Bitcoin: now = 0.5 × 65000 = 32500; prev = 0.5 × (65000 - 1500) = 31750
        // Ethereum: now = 1.0 × 3500 = 3500; prev = 1.0 × (3500 - (-50)) = 3550
        // Combined: now = 36000, prev = 35300
        // change = (36000 - 35300) / 35300 × 100 ≈ 1.9830...
        let now = 0.5 * 65000.0 + 1.0 * 3500.0
        let prev = 0.5 * (65000.0 - 1500.0) + 1.0 * (3500.0 - (-50.0))
        let expectedChange = ((now - prev) / prev) * 100

        XCTAssertEqual(
            store.state.portfolio24HChange ?? .nan,
            expectedChange,
            accuracy: 1e-6
        )
    }

    // MARK: - AC4 (D3): nil priceChange24H is treated as 0 — basket consistent with portfolioValue

    @MainActor
    func testPortfolio24HChangeIsZeroWhenAllPriceChangesAreNil() async {
        var state = HomeFeature.State()
        let bitcoinNoChange = CoinModel(
            id: "bitcoin", symbol: "btc", name: "Bitcoin", image: "",
            currentPrice: 65000.0,
            marketCap: nil, marketCapRank: nil, fullyDilutedValuation: nil, totalVolume: nil,
            high24H: nil, low24H: nil,
            priceChange24H: nil,
            priceChangePercentage24H: nil,
            marketCapChange24H: nil, marketCapChangePercentage24H: nil,
            circulatingSupply: nil, totalSupply: nil, maxSupply: nil,
            ath: nil, athChangePercentage: nil, athDate: nil,
            atl: nil, atlChangePercentage: nil, atlDate: nil,
            lastUpdated: nil, sparklineIn7D: nil, currentHoldings: nil
        )
        state.coins = [bitcoinNoChange]
        state.$portfolioItems.withLock {
            $0 = [PortfolioItem(coinID: "bitcoin", amount: 0.5)]
        }

        let store = TestStore(initialState: state) { HomeFeature() }

        // A coin with non-nil price but nil priceChange24H contributes price*amount to BOTH
        // `current` and `previous` (treating change as 0). The portfolio value matches the
        // priced basket; the percentage reads as 0% movement (we have no signal to suggest
        // otherwise). Same denominator on both sides keeps the value/percent baskets aligned.
        XCTAssertEqual(store.state.portfolioValue, 0.5 * 65000.0, accuracy: 1e-6)
        XCTAssertEqual(store.state.portfolio24HChange ?? .nan, 0, accuracy: 1e-6)
        XCTAssertEqual(store.state.portfolioStatistic?.percentageChange ?? .nan, 0, accuracy: 1e-6)
    }
}

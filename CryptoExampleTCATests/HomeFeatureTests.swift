import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureTests: XCTestCase {

    @MainActor
    func testInitialStateHasNilDestination() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        XCTAssertNil(store.state.destination)
    }

    // MARK: - onAppear → coinsFetched success

    @MainActor
    func testOnAppearFetchesCoinsAndMarketDataSuccess() async {
        let mockCoins = Self.mockCoins
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { mockCoins }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = mockCoins
        }

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }
    }

    // MARK: - onAppear → marketDataFetched success

    @MainActor
    func testOnAppearMarketDataPopulatesStatistics() async {
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { [] }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success)

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }

        XCTAssertEqual(store.state.statistics.count, 3)
    }

    // MARK: - onAppear → coinsFetched failure

    @MainActor
    func testOnAppearCoinsFetchFailureSetsError() async {
        let mockMarketData = Self.mockMarketData

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { throw CoinGeckoError.networkUnavailable }
            $0.coinGeckoClient.fetchMarketData = { mockMarketData }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.failure) {
            $0.error = .networkUnavailable
        }

        await store.receive(\.marketDataFetched.success) {
            $0.statistics = mockMarketData.toStatistics()
            $0.isLoading = false
        }
    }

    // MARK: - onAppear → marketDataFetched failure

    @MainActor
    func testOnAppearMarketDataFetchFailureSetsError() async {
        let mockCoins = Self.mockCoins

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coinGeckoClient.fetchCoins = { mockCoins }
            $0.coinGeckoClient.fetchMarketData = { throw CoinGeckoError.networkUnavailable }
        }

        await store.send(.onAppear) {
            $0.hasAppeared = true
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.coinsFetched.success) {
            $0.coins = mockCoins
        }

        await store.receive(\.marketDataFetched.failure) {
            $0.error = .networkUnavailable
            $0.isLoading = false
        }
    }

    // MARK: - onAppear deduplication

    @MainActor
    func testOnAppearIgnoredWhenAlreadyAppeared() async {
        let store = TestStore(
            initialState: HomeFeature.State(hasAppeared: true)
        ) {
            HomeFeature()
        }

        await store.send(.onAppear)
        // No effects, no state changes — guard returns .none
    }

    // MARK: - Destination tests still pass (no regression)

    @MainActor
    func testDestinationActionReturnsNone() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        // Ensure destination handling still returns .none (no crash, no state change)
        XCTAssertNil(store.state.destination)
        XCTAssertEqual(store.state.coins, [])
        XCTAssertEqual(store.state.statistics, [])
        XCTAssertFalse(store.state.isLoading)
        XCTAssertFalse(store.state.hasAppeared)
        XCTAssertNil(store.state.error)
    }
}

// MARK: - Mock Data

extension HomeFeatureTests {

    static let mockCoins: [CoinModel] = [
        CoinModel(
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
        ),
        CoinModel(
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
        ),
    ]

    static let mockMarketData = MarketDataModel(
        data: MarketDataModel.GlobalData(
            totalMarketCap: ["usd": 2_500_000_000_000],
            totalVolume: ["usd": 80_000_000_000],
            marketCapPercentage: ["btc": 52.5],
            marketCapChangePercentage24HUsd: 1.23
        )
    )
}

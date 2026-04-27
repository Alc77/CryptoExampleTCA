import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class PortfolioBoundsTests: XCTestCase {

    // MARK: - 4.6: saveButtonTapped no-ops on astronomical amount

    @MainActor
    func testSaveButtonTappedNoOpsOnAstronomicalAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [boundsTestBitcoin],
                selectedCoin: boundsTestBitcoin,
                amountText: "1e16"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }

    // MARK: - 4.6: saveButtonTapped no-ops on subnormal amount

    @MainActor
    func testSaveButtonTappedNoOpsOnSubnormalAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [boundsTestBitcoin],
                selectedCoin: boundsTestBitcoin,
                amountText: "5e-324"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }
}

private let boundsTestBitcoin = CoinModel(
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

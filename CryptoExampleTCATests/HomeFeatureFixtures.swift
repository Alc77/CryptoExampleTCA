import Foundation
@testable import CryptoExampleTCA

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
        CoinModel(
            id: "cardano",
            symbol: "ada",
            name: "Cardano",
            image: "https://example.com/ada.png",
            currentPrice: 0.45,
            marketCap: 16_000_000_000,
            marketCapRank: 9,
            fullyDilutedValuation: 20_000_000_000,
            totalVolume: 300_000_000,
            high24H: 0.46,
            low24H: 0.44,
            priceChange24H: 0.005,
            priceChangePercentage24H: 1.12,
            marketCapChange24H: 150_000_000,
            marketCapChangePercentage24H: 0.95,
            circulatingSupply: 35_000_000_000,
            totalSupply: 45_000_000_000,
            maxSupply: 45_000_000_000,
            ath: 3.10,
            athChangePercentage: -85.48,
            athDate: "2021-09-02",
            atl: 0.01735,
            atlChangePercentage: 2493.66,
            atlDate: "2020-03-13",
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

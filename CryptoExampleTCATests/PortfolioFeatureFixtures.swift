import Foundation
@testable import CryptoExampleTCA

extension PortfolioFeatureTests {

    static let bitcoin = CoinModel(
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

    static let ethereum = CoinModel(
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
}

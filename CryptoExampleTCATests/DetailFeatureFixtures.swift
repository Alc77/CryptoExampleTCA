import Foundation
@testable import CryptoExampleTCA

extension DetailFeatureTests {
    static let mockCoin = CoinModel(
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

    static let mockCoinDetail = CoinDetailModel(
        id: "bitcoin",
        symbol: "btc",
        name: "Bitcoin",
        blockTimeInMinutes: 10,
        hashingAlgorithm: "SHA-256",
        description: CoinDetailModel.Description(en: "Bitcoin is..."),
        links: CoinDetailModel.Links(
            homepage: ["https://bitcoin.org"],
            subredditUrl: "https://reddit.com/r/bitcoin"
        ),
        image: CoinDetailModel.CoinImage(
            thumb: "https://example.com/thumb.png",
            small: "https://example.com/small.png",
            large: "https://example.com/large.png"
        ),
        marketCapRank: 1,
        genesisDate: "2009-01-03",
        marketData: CoinDetailModel.MarketData(
            currentPrice: ["usd": 65000],
            marketCap: ["usd": 1_200_000_000_000],
            totalVolume: ["usd": 30_000_000_000],
            high24H: ["usd": 66000],
            low24H: ["usd": 64000],
            priceChange24H: 1500,
            priceChangePercentage24H: 2.35,
            priceChangePercentage7D: 5.50,
            priceChangePercentage14D: nil,
            priceChangePercentage30D: nil,
            priceChangePercentage60D: nil,
            ath: ["usd": 73000],
            athChangePercentage: ["usd": -10.96],
            atl: ["usd": 67.81],
            atlChangePercentage: ["usd": 95000],
            sparkline7D: nil,
            circulatingSupply: 19_500_000,
            totalSupply: 21_000_000,
            maxSupply: 21_000_000
        )
    )

    static let mockSparklinePrices: [Double] = stride(from: 0, through: 167, by: 1).map { hour in
        let base = 65000.0
        let drift = sin(Double(hour) / 12.0) * 1500
        return base + drift
    }

    static let mockCoinDetailWithSparkline: CoinDetailModel = {
        let base = DetailFeatureTests.mockCoinDetail
        return CoinDetailModel(
            id: base.id,
            symbol: base.symbol,
            name: base.name,
            blockTimeInMinutes: base.blockTimeInMinutes,
            hashingAlgorithm: base.hashingAlgorithm,
            description: base.description,
            links: base.links,
            image: base.image,
            marketCapRank: base.marketCapRank,
            genesisDate: base.genesisDate,
            marketData: CoinDetailModel.MarketData(
                currentPrice: base.marketData.currentPrice,
                marketCap: base.marketData.marketCap,
                totalVolume: base.marketData.totalVolume,
                high24H: base.marketData.high24H,
                low24H: base.marketData.low24H,
                priceChange24H: base.marketData.priceChange24H,
                priceChangePercentage24H: base.marketData.priceChangePercentage24H,
                priceChangePercentage7D: base.marketData.priceChangePercentage7D,
                priceChangePercentage14D: base.marketData.priceChangePercentage14D,
                priceChangePercentage30D: base.marketData.priceChangePercentage30D,
                priceChangePercentage60D: base.marketData.priceChangePercentage60D,
                ath: base.marketData.ath,
                athChangePercentage: base.marketData.athChangePercentage,
                atl: base.marketData.atl,
                atlChangePercentage: base.marketData.atlChangePercentage,
                sparkline7D: CoinModel.SparklineIn7D(price: DetailFeatureTests.mockSparklinePrices),
                circulatingSupply: base.marketData.circulatingSupply,
                totalSupply: base.marketData.totalSupply,
                maxSupply: base.marketData.maxSupply
            )
        )
    }()
}

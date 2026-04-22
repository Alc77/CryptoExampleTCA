import Foundation

struct CoinDetailModel: Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let blockTimeInMinutes: Int?
    let hashingAlgorithm: String?
    let description: Description
    let links: Links
    let image: CoinImage
    let marketCapRank: Int?
    let genesisDate: String?
    let marketData: MarketData

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case blockTimeInMinutes = "block_time_in_minutes"
        case hashingAlgorithm = "hashing_algorithm"
        case description
        case links
        case image
        case marketCapRank = "market_cap_rank"
        case genesisDate = "genesis_date"
        case marketData = "market_data"
    }

    struct Description: Codable, Equatable {
        let en: String?
    }

    struct Links: Codable, Equatable {
        let homepage: [String]
        let subredditUrl: String?

        enum CodingKeys: String, CodingKey {
            case homepage
            case subredditUrl = "subreddit_url"
        }
    }

    struct CoinImage: Codable, Equatable {
        let thumb: String
        let small: String
        let large: String
    }

    struct MarketData: Codable, Equatable {
        let currentPrice: [String: Double]
        let marketCap: [String: Double]
        let totalVolume: [String: Double]
        let high24H: [String: Double]
        let low24H: [String: Double]
        let priceChange24H: Double?
        let priceChangePercentage24H: Double?
        let priceChangePercentage7D: Double?
        let priceChangePercentage14D: Double?
        let priceChangePercentage30D: Double?
        let priceChangePercentage60D: Double?
        let ath: [String: Double]
        let athChangePercentage: [String: Double]
        let atl: [String: Double]
        let atlChangePercentage: [String: Double]
        let sparkline7D: CoinModel.SparklineIn7D?
        let circulatingSupply: Double?
        let totalSupply: Double?
        let maxSupply: Double?

        enum CodingKeys: String, CodingKey {
            case currentPrice = "current_price"
            case marketCap = "market_cap"
            case totalVolume = "total_volume"
            case high24H = "high_24h"
            case low24H = "low_24h"
            case priceChange24H = "price_change_24h"
            case priceChangePercentage24H = "price_change_percentage_24h"
            case priceChangePercentage7D = "price_change_percentage_7d"
            case priceChangePercentage14D = "price_change_percentage_14d"
            case priceChangePercentage30D = "price_change_percentage_30d"
            case priceChangePercentage60D = "price_change_percentage_60d"
            case ath
            case athChangePercentage = "ath_change_percentage"
            case atl
            case atlChangePercentage = "atl_change_percentage"
            case sparkline7D = "sparkline_7d"
            case circulatingSupply = "circulating_supply"
            case totalSupply = "total_supply"
            case maxSupply = "max_supply"
        }
    }
}

extension CoinDetailModel {
    func toOverviewStatistics() -> [StatisticModel] {
        let price = StatisticModel(
            title: String(localized: "detail.stats.price"),
            value: marketData.currentPrice["usd"].map { $0.asCurrencyWith6Decimals() } ?? "—",
            percentageChange: marketData.priceChangePercentage24H
        )
        let marketCap = StatisticModel(
            title: String(localized: "detail.stats.marketCap"),
            value: marketData.marketCap["usd"].map { "$" + $0.asBigNumber() } ?? "—",
            percentageChange: marketData.priceChangePercentage24H
        )
        let rank = StatisticModel(
            title: String(localized: "detail.stats.rank"),
            value: marketCapRank.map(String.init) ?? "—"
        )
        let volume = StatisticModel(
            title: String(localized: "detail.stats.volume"),
            value: marketData.totalVolume["usd"].map { "$" + $0.asBigNumber() } ?? "—"
        )
        return [price, marketCap, rank, volume]
    }

    func toAdditionalStatistics() -> [StatisticModel] {
        let blockTime = StatisticModel(
            title: String(localized: "detail.stats.blockTime"),
            value: blockTimeInMinutes.map { "\($0) min" } ?? "—"
        )
        let algorithm = StatisticModel(
            title: String(localized: "detail.stats.hashingAlgorithm"),
            value: hashingAlgorithm ?? "—"
        )
        let circulating = StatisticModel(
            title: String(localized: "detail.stats.circulatingSupply"),
            value: marketData.circulatingSupply.map { $0.asBigNumber() } ?? "—"
        )
        let maxSupplyStat = StatisticModel(
            title: String(localized: "detail.stats.maxSupply"),
            value: marketData.maxSupply.map { $0.asBigNumber() } ?? "—"
        )
        let trimmedGenesis = genesisDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let genesis = StatisticModel(
            title: String(localized: "detail.stats.genesisDate"),
            value: trimmedGenesis.isEmpty ? "—" : trimmedGenesis
        )
        return [blockTime, algorithm, circulating, maxSupplyStat, genesis]
    }
}

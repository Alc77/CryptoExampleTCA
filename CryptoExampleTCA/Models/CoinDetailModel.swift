import Foundation

struct CoinDetailModel: Codable {
    let id: String
    let symbol: String
    let name: String
    let blockTimeInMinutes: Int?
    let hashingAlgorithm: String?
    let description: Description
    let links: Links
    let image: CoinImage
    let marketCapRank: Int?
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
        case marketData = "market_data"
    }

    struct Description: Codable {
        let en: String?
    }

    struct Links: Codable {
        let homepage: [String]
        let subredditUrl: String?

        enum CodingKeys: String, CodingKey {
            case homepage
            case subredditUrl = "subreddit_url"
        }
    }

    struct CoinImage: Codable {
        let thumb: String
        let small: String
        let large: String
    }

    struct MarketData: Codable {
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
        }
    }
}

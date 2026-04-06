import Foundation

struct MarketDataModel: Codable, Equatable {
    let data: GlobalData

    struct GlobalData: Codable, Equatable {
        let totalMarketCap: [String: Double]
        let totalVolume: [String: Double]
        let marketCapPercentage: [String: Double]
        let marketCapChangePercentage24HUsd: Double

        enum CodingKeys: String, CodingKey {
            case totalMarketCap = "total_market_cap"
            case totalVolume = "total_volume"
            case marketCapPercentage = "market_cap_percentage"
            case marketCapChangePercentage24HUsd = "market_cap_change_percentage_24h_usd"
        }
    }

    func toStatistics() -> [StatisticModel] {
        let marketCap = StatisticModel(
            title: String(localized: "stats.marketCap"),
            value: (data.totalMarketCap["usd"] ?? 0).asBigNumber(),
            percentageChange: data.marketCapChangePercentage24HUsd
        )
        let volume = StatisticModel(
            title: String(localized: "stats.volume"),
            value: (data.totalVolume["usd"] ?? 0).asBigNumber()
        )
        let btcDominance = StatisticModel(
            title: String(localized: "stats.btcDominance"),
            value: (data.marketCapPercentage["btc"] ?? 0).asPercentString()
        )
        return [marketCap, volume, btcDominance]
    }
}

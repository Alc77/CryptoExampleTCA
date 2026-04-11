import Foundation

enum CoinGeckoError: Error, Equatable {
    case badResponse(statusCode: Int)
    case decodingFailed
    case rateLimited
    case networkUnavailable
}

extension CoinGeckoError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "error.coingecko.networkUnavailable")
        case .rateLimited:
            return String(localized: "error.coingecko.rateLimited")
        case .decodingFailed:
            return String(localized: "error.coingecko.decodingFailed")
        case .badResponse(let statusCode):
            return String(
                format: String(localized: "error.coingecko.badResponse"),
                statusCode
            )
        }
    }
}

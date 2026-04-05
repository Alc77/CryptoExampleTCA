enum CoinGeckoError: Error, Equatable {
    case badResponse(statusCode: Int)
    case decodingFailed
    case rateLimited
    case networkUnavailable
}

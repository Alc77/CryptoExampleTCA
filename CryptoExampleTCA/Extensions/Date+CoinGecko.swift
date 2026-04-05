import Foundation

extension Date {
    /// Parses CoinGecko ISO 8601 date strings.
    /// Tries fractional seconds first (e.g. "2021-11-10T14:24:11.849Z"),
    /// then falls back to whole-second format (e.g. "2015-10-20T00:00:00Z").
    init?(coinGeckoString: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: coinGeckoString) {
            self = date
            return
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        guard let date = fallback.date(from: coinGeckoString) else { return nil }
        self = date
    }

    /// Formats as "Nov 10, 2021" for UI display.
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

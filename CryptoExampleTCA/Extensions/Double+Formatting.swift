import Foundation

extension Double {

    /// Locale-aware currency formatting covering the full crypto price range.
    /// - >= $1: 2 decimal places ($1,234.56)
    /// - $0.01–$0.99: 4 decimal places ($0.0123)
    /// - < $0.01: 6 decimal places ($0.000123)
    func asCurrencyWith6Decimals() -> String {
        guard !isNaN && !isInfinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = "USD"

        let absValue = abs(self)
        if absValue >= 1.0 {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        } else if absValue >= 0.01 {
            formatter.maximumFractionDigits = 4
            formatter.minimumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 6
            formatter.minimumFractionDigits = 6
        }

        return formatter.string(from: NSNumber(value: self)) ?? "–"
    }

    /// Locale-aware currency with 2 decimal places, for market cap display.
    func asCurrencyWith2Decimals() -> String {
        guard !isNaN && !isInfinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "–"
    }

    /// Percentage string with explicit +/- sign. Pass raw API percent values (e.g. 1.5 for 1.5%).
    func asPercentString() -> String {
        guard !isNaN && !isInfinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.positivePrefix = self == 0 ? "" : "+"
        formatter.negativePrefix = "-"
        return formatter.string(from: NSNumber(value: self / 100)) ?? "–"
    }

    /// Abbreviated with K/M/B/T suffix for large numbers (volumes, market caps).
    func asBigNumber() -> String {
        guard !isNaN && !isInfinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""

        switch absValue {
        case 1_000_000_000_000...:
            let value = absValue / 1_000_000_000_000
            return sign + (formatter.string(from: NSNumber(value: value)) ?? "–") + "T"
        case 1_000_000_000...:
            let value = absValue / 1_000_000_000
            return sign + (formatter.string(from: NSNumber(value: value)) ?? "–") + "B"
        case 1_000_000...:
            let value = absValue / 1_000_000
            return sign + (formatter.string(from: NSNumber(value: value)) ?? "–") + "M"
        case 1_000...:
            let value = absValue / 1_000
            return sign + (formatter.string(from: NSNumber(value: value)) ?? "–") + "K"
        default:
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return sign + (formatter.string(from: NSNumber(value: absValue)) ?? "–")
        }
    }

    /// 2 decimal places, no currency symbol.
    func asNumberString() -> String {
        guard !isNaN && !isInfinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "–"
    }
}

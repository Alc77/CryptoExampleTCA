import Foundation

struct StatisticModel: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let percentageChange: Double?

    init(title: String, value: String, percentageChange: Double? = nil) {
        self.id = title
        self.title = title
        self.value = value
        self.percentageChange = percentageChange
    }
}

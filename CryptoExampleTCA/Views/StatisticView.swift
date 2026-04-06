import SwiftUI

struct StatisticView: View {
    let stat: StatisticModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            Text(stat.value)
                .font(.headline)
                .foregroundStyle(.primary)

            if let percentageChange = stat.percentageChange {
                Text(percentageChange.asPercentString())
                    .font(.caption)
                    .foregroundStyle(
                        percentageChange >= 0
                            ? Color.green
                            : Color.red
                    )
            }
        }
        .padding()
    }
}

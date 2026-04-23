import SwiftUI

struct ChartView: View {
    let prices: [Double]
    let startDate: Date
    let endDate: Date
    let priceChange: Double?

    @State private var percentage: CGFloat = 0
    private let chartHeight: CGFloat = 200

    var body: some View {
        if prices.count < 2 {
            Text(String(localized: "detail.chart.empty"))
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        } else {
            loadedChart
        }
    }

    private var loadedChart: some View {
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 0
        let range = max(maxPrice - minPrice, .leastNormalMagnitude)
        let lineColor: Color = priceChange.map { $0 >= 0 ? .green : .red } ?? .accent

        return VStack(spacing: 4) {
            priceRangeLabels(min: minPrice, max: maxPrice)
            chartPath(minPrice: minPrice, range: range, color: lineColor)
                .frame(height: chartHeight)
            dateRangeLabels
        }
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .onAppear { withAnimation(.linear(duration: 2.0)) { percentage = 1.0 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("detail.chart.accessibility.label"))
        .accessibilityValue(Text(a11yValue(min: minPrice, max: maxPrice)))
    }

    private func chartPath(minPrice: Double, range: Double, color: Color) -> some View {
        GeometryReader { geometry in
            Path { path in
                for index in prices.indices {
                    let xPosition = geometry.size.width / CGFloat(prices.count - 1) * CGFloat(index)
                    let yAxis = prices[index] - minPrice
                    let yPosition = (1 - CGFloat(yAxis / range)) * geometry.size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .trim(from: 0, to: percentage)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color, radius: 10, x: 0, y: 10)
        }
    }

    private func priceRangeLabels(min: Double, max: Double) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Text(max.asCurrencyWith6Decimals())
                Spacer()
                Text(min.asCurrencyWith6Decimals())
            }
        }
    }

    private var dateRangeLabels: some View {
        HStack {
            Text(startDate.shortDateString)
            Spacer()
            Text(endDate.shortDateString)
        }
    }

    private func a11yValue(min: Double, max: Double) -> String {
        var parts = [
            String(format: String(localized: "detail.chart.accessibility.min"), min.asCurrencyWith6Decimals()),
            String(format: String(localized: "detail.chart.accessibility.max"), max.asCurrencyWith6Decimals())
        ]
        if let change = priceChange {
            parts.append(String(format: String(localized: "detail.chart.accessibility.change"), change.asPercentString()))
        }
        return parts.joined(separator: ", ")
    }
}

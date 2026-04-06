import SwiftUI

struct CoinRowView: View {
    let coin: CoinModel

    var body: some View {
        HStack(spacing: 0) {
            // Rank
            Text("\(coin.marketCapRank ?? 0)")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .frame(minWidth: 30, alignment: .center)

            // Coin info
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(coin.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.leading, 4)

            Spacer()

            // Price and change
            VStack(alignment: .trailing, spacing: 4) {
                Text((coin.currentPrice ?? 0).asCurrencyWith6Decimals())
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text((coin.priceChangePercentage24H ?? 0).asPercentString())
                    .font(.subheadline)
                    .foregroundStyle(
                        (coin.priceChangePercentage24H ?? 0) >= 0
                            ? Color.green
                            : Color.red
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

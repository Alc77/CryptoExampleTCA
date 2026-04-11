import SwiftUI

struct ErrorView: View {
    let error: CoinGeckoError
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("error.title")
                    .font(.headline)

                Text(error.errorDescription ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .accessibilityElement(children: .combine)

            Button {
                retryAction()
            } label: {
                Text("error.retry.button")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorView(error: .networkUnavailable, retryAction: {})
}

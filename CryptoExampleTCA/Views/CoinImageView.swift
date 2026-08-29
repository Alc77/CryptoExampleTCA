import SwiftUI
import UIKit

/// Stateless icon slot: the decoded image, a spinner while it is in flight, or a static
/// fallback when no image can ever arrive. Owns no state, no store, and no `@Dependency` —
/// every input is passed in, and the **caller owns the frame** (see `CoinRowView`).
struct CoinImageView: View {
    /// The decoded icon, or `nil` when it has not been loaded — yet, or ever.
    let image: UIImage?

    /// `true` when no image can arrive for this slot: the coin's `image` string is not a
    /// usable http(s) URL, or a load for it already failed. Renders the fallback instead
    /// of a `ProgressView` that would spin forever.
    let isUnavailable: Bool

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else if isUnavailable {
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundStyle(Color.secondaryText)
                .accessibilityHidden(true)
        } else {
            ProgressView()      // FR22
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        CoinImageView(image: UIImage(systemName: "bitcoinsign.circle.fill"), isUnavailable: false)
            .frame(width: 30, height: 30)
        CoinImageView(image: nil, isUnavailable: false)
            .frame(width: 30, height: 30)
        CoinImageView(image: nil, isUnavailable: true)
            .frame(width: 30, height: 30)
    }
}

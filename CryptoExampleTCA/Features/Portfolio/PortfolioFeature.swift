import ComposableArchitecture
import SwiftUI

@Reducer
struct PortfolioFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

// MARK: - View

struct PortfolioView: View {
    let store: StoreOf<PortfolioFeature>

    var body: some View {
        Text("portfolio.placeholder")
            .padding()
    }
}

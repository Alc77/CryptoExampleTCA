import ComposableArchitecture
import SwiftUI

@Reducer
struct DetailFeature {
    @ObservableState
    struct State: Equatable {
        let coin: CoinModel
    }

    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

// MARK: - View

struct DetailView: View {
    let store: StoreOf<DetailFeature>

    var body: some View {
        Text(store.coin.name)
            .navigationTitle(store.coin.name)
    }
}

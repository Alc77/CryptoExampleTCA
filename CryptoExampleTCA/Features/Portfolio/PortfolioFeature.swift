import ComposableArchitecture

@Reducer
struct PortfolioFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

import ComposableArchitecture

@Reducer
struct DetailFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

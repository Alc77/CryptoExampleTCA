import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var coins: [CoinModel] = []
        var statistics: [StatisticModel] = []
        var isLoading = false
        var hasAppeared = false
        var error: CoinGeckoError?
        var searchText: String = ""
        var searchQuery: String = ""

        var filteredCoins: [CoinModel] {
            let query = searchQuery.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return coins }
            return coins.filter { coin in
                coin.name.localizedCaseInsensitiveContains(query)
                    || coin.symbol.localizedCaseInsensitiveContains(query)
            }
        }
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case onAppear
        case reloadButtonTapped
        case coinsFetched(TaskResult<[CoinModel]>)
        case marketDataFetched(TaskResult<MarketDataModel>)
        case searchTextChanged(String)
        case searchCommitted
    }

    private enum FetchID { case fetch }
    private enum SearchDebounceID { case debounce }

    @Dependency(\.coinGeckoClient) var coinGeckoClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination:
                return .none

            case .onAppear:
                guard !state.hasAppeared else { return .none }
                state.hasAppeared = true
                state.isLoading = true
                state.error = nil
                return .run { send in
                    await send(.coinsFetched(
                        TaskResult { try await coinGeckoClient.fetchCoins() }
                    ))
                    await send(.marketDataFetched(
                        TaskResult { try await coinGeckoClient.fetchMarketData() }
                    ))
                }
                .cancellable(id: FetchID.fetch, cancelInFlight: true)

            case .reloadButtonTapped:
                hapticClient.impact()
                state.isLoading = true
                state.error = nil
                return .run { send in
                    await send(.coinsFetched(
                        TaskResult { try await coinGeckoClient.fetchCoins() }
                    ))
                    await send(.marketDataFetched(
                        TaskResult { try await coinGeckoClient.fetchMarketData() }
                    ))
                }
                .cancellable(id: FetchID.fetch, cancelInFlight: true)

            case let .coinsFetched(.success(coins)):
                state.coins = coins
                return .none

            case let .coinsFetched(.failure(error)):
                state.error = error as? CoinGeckoError ?? .networkUnavailable
                return .none

            case let .marketDataFetched(.success(marketData)):
                state.statistics = marketData.toStatistics()
                state.isLoading = false
                return .none

            case let .marketDataFetched(.failure(error)):
                state.error = error as? CoinGeckoError ?? .networkUnavailable
                state.isLoading = false
                return .none

            case let .searchTextChanged(text):
                guard text != state.searchText else { return .none }
                state.searchText = text
                return .run { send in
                    try await clock.sleep(for: .seconds(0.5))
                    await send(.searchCommitted)
                }
                .cancellable(id: SearchDebounceID.debounce, cancelInFlight: true)

            case .searchCommitted:
                state.searchQuery = state.searchText
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    @Reducer
    enum Destination {
        case detail(DetailFeature)
        case portfolio(PortfolioFeature)
        case settings(SettingsFeature)
    }
}

extension HomeFeature.Destination.State: Equatable {
}

// MARK: - View

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        ZStack {
            if let error = store.error, !store.isLoading {
                ErrorView(error: error) {
                    store.send(.reloadButtonTapped)
                }
            } else if store.isLoading && store.coins.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    // Statistics row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(store.statistics) { stat in
                                StatisticView(stat: stat)
                            }
                        }
                    }

                    // Coin list
                    List(store.filteredCoins) { coin in
                        CoinRowView(coin: coin)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(String(localized: "home.title"))
        .searchable(
            text: $store.searchText.sending(\.searchTextChanged),
            prompt: Text("home.search.prompt")
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.reloadButtonTapped)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.coinGeckoClient = .previewValue
            }
        )
    }
}

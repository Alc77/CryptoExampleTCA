import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {

    enum SortOption: Equatable {
        case rank
        case price
        case holdings
    }

    enum Tab: Equatable, Hashable {
        case livePrices
        case portfolio
    }

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
        var sortOption: SortOption = .rank
        var sortAscending: Bool = true
        var selectedTab: Tab = .livePrices
        @Shared(.portfolioItems) var portfolioItems: [PortfolioItem] = []

        var filteredCoins: [CoinModel] {
            // Step 1: Tab filter + holdings overlay
            let holdingsMap = Dictionary(
                uniqueKeysWithValues: portfolioItems.map { ($0.coinID, $0.amount) }
            )
            let tabFiltered: [CoinModel]
            switch selectedTab {
            case .livePrices:
                tabFiltered = coins.map { coin in
                    var updated = coin
                    updated.currentHoldings = holdingsMap[coin.id]
                    return updated
                }
            case .portfolio:
                tabFiltered = coins.compactMap { coin in
                    guard let amount = holdingsMap[coin.id], amount > 0 else { return nil }
                    var updated = coin
                    updated.currentHoldings = amount
                    return updated
                }
            }

            // Step 2: Search filter
            let query = searchQuery.trimmingCharacters(in: .whitespaces)
            let filtered: [CoinModel]
            if query.isEmpty {
                filtered = tabFiltered
            } else {
                filtered = tabFiltered.filter { coin in
                    coin.name.localizedCaseInsensitiveContains(query)
                        || coin.symbol.localizedCaseInsensitiveContains(query)
                }
            }

            // Step 3: Sort
            let result: [CoinModel]
            switch sortOption {
            case .rank:
                result = filtered.sorted { ($0.marketCapRank ?? Int.max) < ($1.marketCapRank ?? Int.max) }
            case .price:
                result = filtered.sorted { ($0.currentPrice ?? 0) < ($1.currentPrice ?? 0) }
            case .holdings:
                result = filtered.sorted { $0.currentHoldingsValue < $1.currentHoldingsValue }
            }
            return sortAscending ? result : result.reversed()
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
        case sortOptionSelected(SortOption)
        case tabSelected(Tab)
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

            case let .sortOptionSelected(option):
                if state.sortOption == option {
                    state.sortAscending.toggle()
                } else {
                    state.sortOption = option
                    state.sortAscending = option == .rank
                }
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
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
                    // Tab selector
                    Picker("Tab", selection: $store.selectedTab.sending(\.tabSelected)) {
                        Text("home.tab.livePrices").tag(HomeFeature.Tab.livePrices)
                        Text("home.tab.portfolio").tag(HomeFeature.Tab.portfolio)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Statistics row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(store.statistics) { stat in
                                StatisticView(stat: stat)
                            }
                        }
                    }

                    // Sort header row
                    HStack {
                        sortColumnButton(.rank, label: "home.sort.rank")
                        Spacer()
                        sortColumnButton(.price, label: "home.sort.price")
                        Spacer()
                        sortColumnButton(.holdings, label: "home.sort.holdings")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // Coin list or empty portfolio state
                    if store.selectedTab == .portfolio && store.filteredCoins.isEmpty && !store.isLoading {
                        Spacer()
                        Text("home.portfolio.empty")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(store.filteredCoins) { coin in
                            CoinRowView(coin: coin)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .listStyle(.plain)
                    }
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

    private func sortColumnButton(_ option: HomeFeature.SortOption, label: String) -> some View {
        Button {
            store.send(.sortOptionSelected(option))
        } label: {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(label))
                if store.sortOption == option {
                    Image(systemName: store.sortAscending ? "chevron.up" : "chevron.down")
                }
            }
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

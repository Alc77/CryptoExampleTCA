import ComposableArchitecture
import SwiftUI
import UIKit

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
        var images: [URL: UIImage] = [:]
        var failedImageURLs: Set<URL> = []
        /// URLs with a load effect currently in flight. Keeps the three icon states mutually
        /// exclusive: a slot showing a spinner always has a real request behind it, and a
        /// repeated `.onAppear` for a URL already loading is dropped instead of re-fetching.
        var loadingImageURLs: Set<URL> = []
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

        var portfolioValue: Double {
            let priceMap = Dictionary(
                coins.compactMap { coin -> (String, Double)? in
                    guard let price = coin.currentPrice else { return nil }
                    return (coin.id, price)
                },
                uniquingKeysWith: { first, _ in first }
            )
            return portfolioItems.reduce(into: 0.0) { total, item in
                guard let price = priceMap[item.coinID] else { return }
                total += price * item.amount
            }
        }

        var portfolio24HChange: Double? {
            var current: Double = 0
            var previous: Double = 0
            let coinByID = Dictionary(
                coins.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for item in portfolioItems {
                guard let coin = coinByID[item.coinID],
                      let price = coin.currentPrice else { continue }
                let change = coin.priceChange24H ?? 0
                current += price * item.amount
                previous += (price - change) * item.amount
            }
            guard previous > 0 else { return nil }
            return ((current - previous) / previous) * 100
        }

        var portfolioStatistic: StatisticModel? {
            guard portfolioValue > 0 else { return nil }
            return StatisticModel(
                title: String(localized: "stats.portfolioValue"),
                value: portfolioValue.asCurrencyWith2Decimals(),
                percentageChange: portfolio24HChange
            )
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
        case coinTapped(CoinModel)
        case portfolioButtonTapped
        case tabSelected(Tab)
        case loadImage(URL)
        case imageLoaded(url: URL, result: TaskResult<UIImage>)
    }

    private enum FetchID { case fetch }
    private enum SearchDebounceID { case debounce }
    /// One cancellation id per icon, so a reload can supersede the loads it is retrying
    /// instead of letting their stale results land afterwards.
    private struct ImageLoadID: Hashable { let url: URL }

    /// `coin.image` is unvalidated wire data. `URL(string:)` parses a *relative* string —
    /// CoinGecko serves "missing_large.png" for coins with no artwork — into a scheme-less
    /// URL that `URLSession` can only ever reject. The reducer refuses to fetch it and the
    /// view renders the unavailable fallback rather than a spinner that never stops.
    ///
    /// Schemes are case-insensitive per RFC 3986 and Foundation's normalization varies by
    /// parser, so compare lowercased — `HTTPS://…` names a perfectly fetchable icon.
    static func isLoadableImageURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "https" || scheme == "http"
    }

    @Dependency(\.coinGeckoClient) var coinGeckoClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.imageCache) var imageCache

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
                // AC8 — retry path for failed icons. Clearing the set alone is not enough:
                // `.onAppear` fires on row identity, which a refresh does not change, so a row
                // already on screen would sit on a spinner with no request behind it. Re-dispatch
                // the loads here, and supersede any in-flight ones so their stale results cannot
                // re-mark a URL the user just asked us to retry.
                let retryImageURLs = state.failedImageURLs.union(state.loadingImageURLs)
                let supersededImageLoads = state.loadingImageURLs.map { ImageLoadID(url: $0) }
                state.failedImageURLs.removeAll()
                state.loadingImageURLs.removeAll()
                return .merge(
                    .merge(supersededImageLoads.map { .cancel(id: $0) }),
                    .run { send in
                        for url in retryImageURLs {
                            await send(.loadImage(url))
                        }
                        await send(.coinsFetched(
                            TaskResult { try await coinGeckoClient.fetchCoins() }
                        ))
                        await send(.marketDataFetched(
                            TaskResult { try await coinGeckoClient.fetchMarketData() }
                        ))
                    }
                    .cancellable(id: FetchID.fetch, cancelInFlight: true)
                )

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

            case let .coinTapped(coin):
                guard state.destination == nil else { return .none }
                state.destination = .detail(DetailFeature.State(coin: coin))
                return .none

            case .portfolioButtonTapped:
                guard state.destination == nil else { return .none }
                state.destination = .portfolio(PortfolioFeature.State(coins: state.coins))
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                state.destination = nil
                return .none

            case let .loadImage(url):
                guard Self.isLoadableImageURL(url) else { return .none }
                guard state.images[url] == nil else { return .none }
                guard !state.failedImageURLs.contains(url) else { return .none }   // AC7
                // A row can re-appear (scroll, tab switch, re-sort) long before its first load
                // resolves; without this the same icon is fetched and decoded once per appearance.
                guard state.loadingImageURLs.insert(url).inserted else { return .none }
                return .run { send in
                    await send(.imageLoaded(
                        url: url,
                        result: TaskResult { try await imageCache.image(url) }
                    ))
                }
                .cancellable(id: ImageLoadID(url: url), cancelInFlight: true)

            case let .imageLoaded(url, .success(image)):
                state.loadingImageURLs.remove(url)
                state.failedImageURLs.remove(url)
                state.images[url] = image
                return .none

            case let .imageLoaded(url, .failure):
                state.loadingImageURLs.remove(url)
                state.failedImageURLs.insert(url)          // AC6 — terminal, not infinite
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
                            if let portfolioStat = store.portfolioStatistic {
                                StatisticView(stat: portfolioStat)
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
                            let loadableURL = URL(string: coin.image).flatMap {
                                HomeFeature.isLoadableImageURL($0) ? $0 : nil
                            }
                            Button {
                                store.send(.coinTapped(coin))
                            } label: {
                                CoinRowView(
                                    coin: coin,
                                    image: loadableURL.flatMap { store.images[$0] },
                                    isImageUnavailable: loadableURL.map { store.failedImageURLs.contains($0) } ?? true
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .onAppear {
                                if let loadableURL {
                                    store.send(.loadImage(loadableURL))
                                }
                            }
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    store.send(.portfolioButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("home.portfolio.openButton"))
            }
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
        .navigationDestination(
            item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
        ) { detailStore in
            DetailView(store: detailStore)
        }
        .sheet(
            item: $store.scope(state: \.destination?.portfolio, action: \.destination.portfolio)
        ) { portfolioStore in
            PortfolioView(store: portfolioStore)
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

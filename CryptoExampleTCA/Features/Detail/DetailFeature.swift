import ComposableArchitecture
import SwiftUI

private enum FetchID { case fetch }

@Reducer
struct DetailFeature {
    @ObservableState
    struct State: Equatable {
        let coin: CoinModel
        var coinDetail: CoinDetailModel?
        var isLoading = false
        var error: CoinGeckoError?
    }

    enum Action {
        case onAppear
        case coinDetailFetched(TaskResult<CoinDetailModel>)
    }

    @Dependency(\.coinGeckoClient) var coinGeckoClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.error = nil
                let id = state.coin.id
                return .run { send in
                    await send(.coinDetailFetched(
                        TaskResult { try await coinGeckoClient.fetchCoinDetail(id) }
                    ))
                }
                .cancellable(id: FetchID.fetch, cancelInFlight: true)

            case let .coinDetailFetched(.success(detail)):
                state.isLoading = false
                state.coinDetail = detail
                return .none

            case let .coinDetailFetched(.failure(error)):
                state.isLoading = false
                state.error = error as? CoinGeckoError ?? .networkUnavailable
                return .none
            }
        }
    }
}

// MARK: - View

struct DetailView: View {
    @Bindable var store: StoreOf<DetailFeature>

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.error {
                ErrorView(error: error) {
                    store.send(.onAppear)
                }
            } else if let detail = store.coinDetail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        chartSection(for: detail)

                        sectionHeader("detail.section.overview")
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(detail.toOverviewStatistics()) { stat in
                                StatisticView(stat: stat)
                            }
                        }

                        sectionHeader("detail.section.additional")
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(detail.toAdditionalStatistics()) { stat in
                                StatisticView(stat: stat)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle(store.coin.name)
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private func chartSection(for detail: CoinDetailModel) -> some View {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        ChartView(
            prices: detail.marketData.sparkline7D?.price ?? [],
            startDate: startDate,
            endDate: now,
            priceChange: detail.marketData.priceChangePercentage7D
        )
    }

    private func sectionHeader(_ key: String.LocalizationValue) -> some View {
        Text(String(localized: key))
            .font(.title2.weight(.semibold))
    }
}

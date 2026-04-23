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
        var showFullDescription = false
    }

    enum Action {
        case onAppear
        case coinDetailFetched(TaskResult<CoinDetailModel>)
        case descriptionToggled
        case websiteLinkTapped(URL)
        case redditLinkTapped(URL)
    }

    @Dependency(\.coinGeckoClient) var coinGeckoClient
    @Dependency(\.urlOpener) var urlOpener

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

            case .descriptionToggled:
                state.showFullDescription.toggle()
                return .none

            case let .websiteLinkTapped(url):
                return .run { _ in await urlOpener.open(url) }

            case let .redditLinkTapped(url):
                return .run { _ in await urlOpener.open(url) }
            }
        }
    }
}

// MARK: - Link URL Derivation

private func parsedHTTPURL(from string: String) -> URL? {
    guard let url = URL(string: string),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else { return nil }
    return url
}

fileprivate extension CoinDetailModel.Links {
    var websiteURL: URL? {
        homepage
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
            .flatMap(parsedHTTPURL(from:))
    }

    var redditURL: URL? {
        subredditUrl
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : parsedHTTPURL(from: $0) }
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

                        descriptionSection(for: detail)
                        linksSection(for: detail)
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

    @ViewBuilder
    private func descriptionSection(for detail: CoinDetailModel) -> some View {
        let cleaned = (detail.description.en ?? "")
            .removingHTMLTags
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("detail.section.description")
                Text(cleaned)
                    .font(.callout)
                    .lineLimit(store.showFullDescription ? nil : 3)
                    .animation(.easeInOut, value: store.showFullDescription)
                Button {
                    store.send(.descriptionToggled, animation: .easeInOut)
                } label: {
                    Text(String(localized: store.showFullDescription
                        ? "detail.description.readLess"
                        : "detail.description.readMore"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func linksSection(for detail: CoinDetailModel) -> some View {
        let website = detail.links.websiteURL
        let reddit = detail.links.redditURL
        if website != nil || reddit != nil {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("detail.section.links")
                if let website {
                    Button {
                        store.send(.websiteLinkTapped(website))
                    } label: {
                        linkRow(titleKey: "detail.links.website", systemImage: "globe")
                    }
                }
                if let reddit {
                    Button {
                        store.send(.redditLinkTapped(reddit))
                    } label: {
                        linkRow(titleKey: "detail.links.reddit", systemImage: "bubble.left.and.bubble.right")
                    }
                }
            }
        }
    }

    private func linkRow(titleKey: String.LocalizationValue, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(String(localized: titleKey))
            Spacer()
            Image(systemName: "arrow.up.right.square")
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accent)
        .contentShape(Rectangle())
    }

    private func sectionHeader(_ key: String.LocalizationValue) -> some View {
        Text(String(localized: key))
            .font(.title2.weight(.semibold))
    }
}

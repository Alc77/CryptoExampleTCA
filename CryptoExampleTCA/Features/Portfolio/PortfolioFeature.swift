import ComposableArchitecture
import SwiftUI

@Reducer
struct PortfolioFeature {
    @ObservableState
    struct State: Equatable {
        var coins: [CoinModel] = []
        var selectedCoin: CoinModel?
        var amountText: String = ""
        @Shared(.portfolioItems) var portfolioItems: [PortfolioItem] = []
    }

    enum Action {
        case coinTapped(CoinModel)
        case amountChanged(String)
        case saveButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .coinTapped(coin):
                state.selectedCoin = coin
                if let existing = state.portfolioItems.first(where: { $0.coinID == coin.id }) {
                    state.amountText = Self.format(existing.amount)
                } else {
                    state.amountText = ""
                }
                return .none

            case let .amountChanged(text):
                state.amountText = text
                return .none

            case .saveButtonTapped:
                guard let coin = state.selectedCoin else { return .none }

                let existingIndex = state.portfolioItems.firstIndex(where: { $0.coinID == coin.id })
                let parsedAmount = Double(state.amountText)
                let isRemovalIntent = state.amountText.isEmpty || parsedAmount == .some(0.0)

                if isRemovalIntent {
                    guard let index = existingIndex else { return .none }
                    state.$portfolioItems.withLock { items in
                        _ = items.remove(at: index)
                    }
                } else {
                    guard let amount = parsedAmount, amount.isFinite, amount > 0 else {
                        return .none
                    }
                    state.$portfolioItems.withLock { items in
                        if let index = existingIndex {
                            items[index].amount = amount
                        } else {
                            items.append(PortfolioItem(coinID: coin.id, amount: amount))
                        }
                    }
                }

                state.amountText = ""
                state.selectedCoin = nil
                return .run { _ in await dismiss() }
            }
        }
    }

    private static func format(_ amount: Double) -> String {
        guard amount.isFinite else { return "" }
        if amount == amount.rounded(), let asInt = Int(exactly: amount) {
            return String(asInt)
        }
        return String(amount)
    }
}

// MARK: - View

struct PortfolioView: View {
    @Bindable var store: StoreOf<PortfolioFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let selected = store.selectedCoin {
                    selectedCoinEditor(for: selected)
                }
                List(store.coins) { coin in
                    Button {
                        store.send(.coinTapped(coin))
                    } label: {
                        coinRow(coin)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("portfolio.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func selectedCoinEditor(for coin: CoinModel) -> some View {
        HStack {
            Text(coin.symbol.uppercased())
                .font(.headline)
            Spacer()
            TextField(
                "portfolio.amount.prompt",
                text: $store.amountText.sending(\.amountChanged)
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 120)
            Button("portfolio.save") {
                store.send(.saveButtonTapped)
            }
            .disabled(isSaveDisabled(for: coin))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private func isSaveDisabled(for coin: CoinModel) -> Bool {
        let isExisting = store.portfolioItems.contains { $0.coinID == coin.id }
        if store.amountText.isEmpty {
            return !isExisting
        }
        guard let amount = Double(store.amountText), amount.isFinite else {
            return true
        }
        if amount == 0 {
            return !isExisting
        }
        return amount < 0
    }

    @ViewBuilder
    private func coinRow(_ coin: CoinModel) -> some View {
        HStack {
            Text(coin.symbol.uppercased())
                .font(.headline)
                .frame(width: 60, alignment: .leading)
            Text(coin.name)
            Spacer()
            if let holdings = store.portfolioItems.first(where: { $0.coinID == coin.id })?.amount {
                Text(holdings, format: .number)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

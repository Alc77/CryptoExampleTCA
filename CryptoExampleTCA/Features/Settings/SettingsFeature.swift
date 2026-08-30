import ComposableArchitecture
import SwiftUI

// MARK: - External Links

enum SettingsLink {
    static let coinGecko = URL(string: "https://www.coingecko.com")
    static let developer = URL(string: "https://github.com/Alc77")
}

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var coinGeckoURL: URL? = SettingsLink.coinGecko
        var developerURL: URL? = SettingsLink.developer
    }

    enum Action {
        case dismissButtonTapped
        case coinGeckoLinkTapped
        case developerLinkTapped
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.urlOpener) var urlOpener

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .dismissButtonTapped:
                return .run { _ in await dismiss() }

            case .coinGeckoLinkTapped:
                guard let url = state.coinGeckoURL else { return .none }
                return .run { _ in await urlOpener.open(url) }

            case .developerLinkTapped:
                guard let url = state.developerURL else { return .none }
                return .run { _ in await urlOpener.open(url) }
            }
        }
    }
}

// MARK: - View

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            List {
                appSection
                developerSection
                coinGeckoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("settings.dismiss") {
                        store.send(.dismissButtonTapped)
                    }
                }
            }
        }
    }

    private var appSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Image("logo")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel(Text("settings.app.logo.accessibility"))
                Text("settings.app.description")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.vertical, 8)
        } header: {
            Text("settings.section.app")
        }
    }

    private var coinGeckoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Image("coinGecko")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(Text("settings.coingecko.logo.accessibility"))
                Text("settings.coingecko.attribution")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.vertical, 8)
            if store.coinGeckoURL != nil {
                Button {
                    store.send(.coinGeckoLinkTapped)
                } label: {
                    linkRow(titleKey: "settings.coingecko.link")
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("settings.section.coingecko")
        }
    }

    private var developerSection: some View {
        Section {
            Text("settings.developer.attribution")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
                .padding(.vertical, 8)
            if store.developerURL != nil {
                Button {
                    store.send(.developerLinkTapped)
                } label: {
                    linkRow(titleKey: "settings.developer.link")
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("settings.section.developer")
        }
    }

    private func linkRow(titleKey: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Text(titleKey)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .accessibilityHidden(true)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.accent)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

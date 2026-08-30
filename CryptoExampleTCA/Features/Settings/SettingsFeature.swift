import ComposableArchitecture
import SwiftUI

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case dismissButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .dismissButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}

// MARK: - View

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            VStack {
                Text("settings.placeholder")
                    .foregroundStyle(.secondary)
            }
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
}

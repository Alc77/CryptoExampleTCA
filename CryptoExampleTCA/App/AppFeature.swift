import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var home = HomeFeature.State()
    }

    enum Action {
        case home(HomeFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
    }
}

// MARK: - View

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            HomeView(store: store.scope(state: \.home, action: \.home))
        }
    }
}

// MARK: - Previews

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}

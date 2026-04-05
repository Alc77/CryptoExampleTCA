import ComposableArchitecture
import SwiftUI

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
    }

    enum Action {
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination:
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
    let store: StoreOf<HomeFeature>

    var body: some View {
        Text("home.title")
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }
}

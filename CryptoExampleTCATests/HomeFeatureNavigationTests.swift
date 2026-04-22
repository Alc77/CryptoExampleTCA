import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureNavigationTests: XCTestCase {

    // MARK: - AC4: Tapping a coin sets destination to .detail

    @MainActor
    func testCoinTappedPushesDetailDestination() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.coinTapped(HomeFeatureTests.mockCoins[0])) {
            $0.destination = .detail(DetailFeature.State(coin: HomeFeatureTests.mockCoins[0]))
        }
    }

    // MARK: - AC5: Dismissing clears destination

    @MainActor
    func testDismissDestinationClearsDetail() async {
        var initial = HomeFeature.State()
        initial.destination = .detail(DetailFeature.State(coin: HomeFeatureTests.mockCoins[0]))

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    // MARK: - Rapid-tap guard: second coinTapped is ignored while detail is presented

    @MainActor
    func testCoinTappedIsIgnoredWhenDestinationAlreadyPresented() async {
        var initial = HomeFeature.State()
        initial.destination = .detail(DetailFeature.State(coin: HomeFeatureTests.mockCoins[0]))

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.coinTapped(HomeFeatureTests.mockCoins[1]))
    }

    // MARK: - Tab switch dismisses pushed detail

    @MainActor
    func testTabSelectedClearsDestination() async {
        var initial = HomeFeature.State()
        initial.destination = .detail(DetailFeature.State(coin: HomeFeatureTests.mockCoins[0]))

        let store = TestStore(initialState: initial) {
            HomeFeature()
        }

        await store.send(.tabSelected(.portfolio)) {
            $0.selectedTab = .portfolio
            $0.destination = nil
        }
    }
}

import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class HomeFeatureTests: XCTestCase {

    @MainActor
    func testInitialStateHasNilDestination() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        XCTAssertNil(store.state.destination)
    }
}

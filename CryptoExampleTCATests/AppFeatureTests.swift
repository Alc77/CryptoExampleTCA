import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class AppFeatureTests: XCTestCase {

    @MainActor
    func testInitialStateHasEmptyHomeState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        XCTAssertEqual(store.state.home, HomeFeature.State())
    }
}

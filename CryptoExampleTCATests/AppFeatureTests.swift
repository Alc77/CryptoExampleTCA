import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class AppFeatureTests: XCTestCase {

    override func invokeTest() {
        withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            super.invokeTest()
        }
    }

    @MainActor
    func testInitialStateHasEmptyHomeState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        XCTAssertEqual(store.state.home, HomeFeature.State())
    }
}

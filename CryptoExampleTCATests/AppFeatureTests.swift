import ComposableArchitecture
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct AppFeatureTests {

        @Test func initialStateHasEmptyHomeState() async {
            let store = TestStore(initialState: AppFeature.State()) {
                AppFeature()
            }
            #expect(store.state.home == HomeFeature.State())
        }
    }
}

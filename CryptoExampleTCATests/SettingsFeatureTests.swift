import ComposableArchitecture
import Testing

extension BaseSuite {
    @MainActor
    @Suite struct SettingsFeatureTests {

        // MARK: - AC5/AC9: dismissButtonTapped runs the dismiss effect

        @Test func dismissButtonTappedDismissesSheet() async {
            let didDismiss = LockIsolated(false)

            let store = TestStore(initialState: SettingsFeature.State()) {
                SettingsFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { didDismiss.setValue(true) }
            }

            await store.send(.dismissButtonTapped)
            await store.finish()

            #expect(didDismiss.value)
        }
    }
}

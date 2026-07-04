import Testing

extension BaseSuite {
    @Suite struct HapticClientTests {

        @Test func liveValueImpactIsCallableWithoutCrash() {
            HapticClient.liveValue.impact()
        }

        @Test func testValueImpactIsCallableWithoutCrash() {
            HapticClient.testValue.impact()
        }

        @Test func previewValueImpactIsCallableWithoutCrash() {
            HapticClient.previewValue.impact()
        }
    }
}

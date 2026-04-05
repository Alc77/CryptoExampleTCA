import XCTest
@testable import CryptoExampleTCA

final class HapticClientTests: XCTestCase {

    func testLiveValueImpactIsCallableWithoutCrash() {
        let client = HapticClient.liveValue
        client.impact()
    }

    func testTestValueImpactIsCallableWithoutCrash() {
        let client = HapticClient.testValue
        client.impact()
    }

    func testPreviewValueImpactIsCallableWithoutCrash() {
        let client = HapticClient.previewValue
        client.impact()
    }
}

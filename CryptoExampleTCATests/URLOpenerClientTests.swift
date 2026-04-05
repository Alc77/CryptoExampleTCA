import XCTest
@testable import CryptoExampleTCA

final class URLOpenerClientTests: XCTestCase {

    func testOpenPassesCorrectURL() async {
        let expectedURL = URL(string: "https://example.com")!
        let capture = URLCapture()

        let client = URLOpenerClient(open: { url in
            await capture.set(url)
        })

        await client.open(expectedURL)

        let capturedURL = await capture.url
        XCTAssertEqual(capturedURL, expectedURL)
    }

    func testTestValueIsCallableWithoutCrash() async {
        let client = URLOpenerClient.testValue
        await client.open(URL(string: "https://example.com")!)
    }

    func testPreviewValueIsCallableWithoutCrash() async {
        let client = URLOpenerClient.previewValue
        await client.open(URL(string: "https://example.com")!)
    }
}

private actor URLCapture {
    var url: URL?

    func set(_ url: URL) {
        self.url = url
    }
}

import Foundation
import Testing

extension BaseSuite {
    @Suite struct URLOpenerClientTests {

        @Test func openPassesCorrectURL() async throws {
            let expectedURL = try #require(URL(string: "https://example.com"))
            let capture = URLCapture()

            let client = URLOpenerClient(open: { url in
                await capture.set(url)
            })

            await client.open(expectedURL)

            let capturedURL = await capture.url
            #expect(capturedURL == expectedURL)
        }

        @Test func testValueIsCallableWithoutCrash() async throws {
            let url = try #require(URL(string: "https://example.com"))
            await URLOpenerClient.testValue.open(url)
        }

        @Test func previewValueIsCallableWithoutCrash() async throws {
            let url = try #require(URL(string: "https://example.com"))
            await URLOpenerClient.previewValue.open(url)
        }
    }
}

private actor URLCapture {
    var url: URL?

    func set(_ url: URL) {
        self.url = url
    }
}

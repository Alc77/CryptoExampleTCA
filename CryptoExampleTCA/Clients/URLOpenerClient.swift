import Dependencies
import UIKit

struct URLOpenerClient: Sendable {
    var open: @Sendable (URL) async -> Void
}

// MARK: - @Dependency Registration

extension URLOpenerClient: DependencyKey {
    static let liveValue = URLOpenerClient(
        open: { url in
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    )
    static let testValue = URLOpenerClient(open: { _ in })
    static let previewValue = URLOpenerClient(open: { _ in })
}

extension DependencyValues {
    var urlOpener: URLOpenerClient {
        get { self[URLOpenerClient.self] }
        set { self[URLOpenerClient.self] = newValue }
    }
}

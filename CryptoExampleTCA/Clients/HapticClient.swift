import Dependencies
import UIKit

struct HapticClient: Sendable {
    var impact: @Sendable () -> Void
}

// MARK: - @Dependency Registration

extension HapticClient: DependencyKey {
    static let liveValue = HapticClient(
        impact: {
            Task { @MainActor in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    )
    static let testValue = HapticClient(impact: {})
    static let previewValue = HapticClient(impact: {})
}

extension DependencyValues {
    var hapticClient: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}

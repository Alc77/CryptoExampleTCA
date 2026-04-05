// CryptoExampleTCA/Persistence/RealmController.swift
import RealmSwift
import Dependencies

// MARK: - SPIKE DECISION (Story 1.5)
// Date: 2026-03-30
// Outcome: ✅ @Shared + Realm confirmed viable
// Approach: RealmPortfolioKey (custom SharedKey) — see RealmPortfolioKey.swift
// Tests passing: RealmControllerTests (round-trip) + PortfolioSpikeTests (TestStore)
// Epic 4 portfolio stories will use @Shared(.portfolioItems) in PortfolioFeature.State

struct RealmController: Sendable {
    let configuration: Realm.Configuration

    static let live = RealmController(
        configuration: Realm.Configuration(schemaVersion: 1)
    )

    static func inMemory(id: String) -> RealmController {
        RealmController(
            configuration: Realm.Configuration(inMemoryIdentifier: id)
        )
    }

    func realm() throws -> Realm {
        try Realm(configuration: configuration)
    }
}

// MARK: - @Dependency Registration

extension RealmController: DependencyKey {
    static let liveValue = RealmController.live
    // NB: Tests must override with a unique identifier via withDependencies to avoid cross-test pollution
    static let testValue = RealmController.inMemory(id: "portfolio-test")
    static let previewValue = RealmController.inMemory(id: "portfolio-preview")
}

extension DependencyValues {
    var realmController: RealmController {
        get { self[RealmController.self] }
        set { self[RealmController.self] = newValue }
    }
}

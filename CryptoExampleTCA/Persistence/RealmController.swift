// CryptoExampleTCA/Persistence/RealmController.swift
import Foundation
import RealmSwift
import Dependencies

// MARK: - SPIKE DECISION (Story 1.5)
// Date: 2026-03-30
// Outcome: ✅ @Shared + Realm confirmed viable
// Approach: RealmPortfolioKey (custom SharedKey) — see RealmPortfolioKey.swift
// Tests passing: RealmControllerTests (round-trip) + PortfolioSpikeTests (TestStore)
// Epic 4 portfolio stories will use @Shared(.portfolioItems) in PortfolioFeature.State

// MARK: - PERSISTENCE GUARANTEES (Story 4.5)
//
// FR18 — Cross-launch persistence:
//   `liveValue` opens `Application Support/default.realm` (Realm's default
//   file URL on iOS sandbox). Data written via `RealmPortfolioKey.save(...)`
//   survives app termination and is restored on the next launch by
//   `RealmPortfolioKey.load(...)` on first `@Shared(.portfolioItems)` read.
//   Verified by PortfolioPersistenceTests.testPortfolioRoundTripsAcrossControllerInstances.
//
// NFR5 — No blocking main-thread init at launch:
//   `Realm(configuration:)` is NEVER called from `@main` /
//   `CryptoExampleTCAApp.body` / root `Store(initialState:)` setup. The
//   first Realm open happens lazily inside `RealmPortfolioKey.load(...)` /
//   `subscribe(...)`, which swift-sharing 2.8.0 invokes only on first
//   `@Shared(.portfolioItems)` access (HomeFeature.State first read).
//
// NFR7 — On-device only:
//   `Realm.Configuration` declares NO `syncConfiguration`. Portfolio data
//   never leaves the device — no CloudKit, no Atlas Device Sync, no
//   network upload path. The persistence boundary is one-way (disk only).
//   Code review must reject any change that adds `syncConfiguration` or
//   exfiltrates `PortfolioObject` / `PortfolioItem` outside the
//   Persistence/ folder.

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

    /// Construct a controller backed by an on-disk Realm at the given file URL.
    /// Used by cross-launch persistence tests in `PortfolioPersistenceTests.swift`
    /// to prove FR18 round-trip behaviour without touching the app's default
    /// `Application Support/default.realm`. Production code MUST use `.live`.
    static func atURL(_ fileURL: URL) -> RealmController {
        RealmController(
            configuration: Realm.Configuration(fileURL: fileURL, schemaVersion: 1)
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

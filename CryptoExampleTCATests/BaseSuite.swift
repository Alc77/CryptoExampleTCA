import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

// Base Swift Testing suite. Every `@Suite` that extends `BaseSuite` inherits these traits:
//
//   • `.serialized` — mirrors `xcodebuild test -parallel-testing-enabled NO` (CLAUDE.md).
//     Realm thread-confinement and `@Shared` cache state make parallel-by-default risky.
//   • `.dependencies { … }` — applies the two isolation overrides that Story 4.6's review
//     surfaced as pollution sources, so no per-suite `invokeTest` override is required:
//       - `realmController = .inMemory(id: UUID().uuidString)` gives each test a fresh Realm.
//       - `coinGeckoClient = .previewValue` yields deterministic mock data instead of the
//         `unimplemented(...)` testValue (which would report an issue) for tests that never
//         override it explicitly.
//
// `httpClient` is intentionally left at its `testValue` (unimplemented) safety net — the tests
// that touch it (CoinGeckoClientTests) override it explicitly per-test with mock JSON, and a
// base default would silently shadow those overrides.
//
// NOTE: the test bundle is hostless and compiles the app's own sources, so there is no
// `@testable import CryptoExampleTCA` — the app types are already in this module.
@Suite(
    .serialized,
    .dependencies {
        $0.realmController = .inMemory(id: UUID().uuidString)
        $0.coinGeckoClient = .previewValue
    }
)
struct BaseSuite {}

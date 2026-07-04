import Foundation
import RealmSwift
import Testing

extension BaseSuite {
    @Suite struct PortfolioPersistenceTests {

        // MARK: - Test fileURL helpers

        private func makeTempRealmURL() -> URL {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).realm")
        }

        private func deleteRealmFiles(at fileURL: URL) {
            // Realm writes a primary file plus auxiliary files (.lock, .management/,
            // .note). All must be removed for a hermetic test environment.
            let fm = FileManager.default
            try? fm.removeItem(at: fileURL)
            try? fm.removeItem(at: fileURL.appendingPathExtension("lock"))
            try? fm.removeItem(at: fileURL.appendingPathExtension("note"))
            try? fm.removeItem(at: fileURL.deletingPathExtension()
                .appendingPathExtension("realm.management"))
        }

        // MARK: - Tests

        @Test func portfolioRoundTripsAcrossControllerInstances() throws {
            let fileURL = makeTempRealmURL()
            defer { deleteRealmFiles(at: fileURL) }

            // Phase 1: simulate the first app launch — write two holdings.
            do {
                let controller = RealmController.atURL(fileURL)
                let realm = try controller.realm()
                try realm.write {
                    let bitcoin = PortfolioObject()
                    bitcoin.coinID = "bitcoin"
                    bitcoin.amount = 1.5
                    let ethereum = PortfolioObject()
                    ethereum.coinID = "ethereum"
                    ethereum.amount = 5.0
                    realm.add(bitcoin, update: .modified)
                    realm.add(ethereum, update: .modified)
                }
                // Drop both `realm` and `controller` — let ARC release them and
                // close the Realm before the second open. swift-realm closes the
                // underlying file handle when the last instance is deallocated.
            }

            // Phase 2: simulate the second app launch — fresh controller at the
            // same fileURL must observe both rows.
            let controller = RealmController.atURL(fileURL)
            let realm = try controller.realm()
            let items = realm.objects(PortfolioObject.self)
                .map { PortfolioItem(coinID: $0.coinID, amount: $0.amount) }
                .sorted { $0.coinID < $1.coinID }

            try #require(items.count == 2)
            #expect(items[0] == PortfolioItem(coinID: "bitcoin", amount: 1.5))
            #expect(items[1] == PortfolioItem(coinID: "ethereum", amount: 5.0))
        }

        @MainActor @Test func realmFileDoesNotExistBeforeFirstSharedAccess() async throws {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).realm")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            #expect(!FileManager.default.fileExists(atPath: tempURL.path),
                    "precondition: temp Realm file must not exist yet")

            let controller = RealmController.atURL(tempURL)
            // Constructing the controller MUST NOT touch disk — Realm.Configuration
            // is a value type; opening happens only when realm() is called.
            #expect(!FileManager.default.fileExists(atPath: tempURL.path),
                    "RealmController(_:) must not open the file lazily")

            _ = try controller.realm()
            #expect(FileManager.default.fileExists(atPath: tempURL.path),
                    "calling realm() must open and create the file")
        }

        @Test func emptyRealmReadsAsEmptyArray() throws {
            let fileURL = makeTempRealmURL()
            defer { deleteRealmFiles(at: fileURL) }

            let controller = RealmController.atURL(fileURL)
            let realm = try controller.realm()
            let items = realm.objects(PortfolioObject.self)
                .map { PortfolioItem(coinID: $0.coinID, amount: $0.amount) }

            #expect(Array(items) == [])
        }
    }
}

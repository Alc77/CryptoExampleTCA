// CryptoExampleTCATests/Persistence/RealmControllerTests.swift
import XCTest
import RealmSwift
@testable import CryptoExampleTCA

final class RealmControllerTests: XCTestCase {

    func testPortfolioItemRoundTrip() throws {
        let realm = try RealmController.inMemory(id: #function).realm()

        try realm.write {
            let obj = PortfolioObject()
            obj.coinID = "bitcoin"
            obj.amount = 1.5
            realm.add(obj)
        }

        let result = realm.objects(PortfolioObject.self).first
        XCTAssertEqual(result?.coinID, "bitcoin")
        XCTAssertEqual(result?.amount, 1.5)
    }

    func testMultipleItemsRoundTrip() throws {
        let realm = try RealmController.inMemory(id: #function).realm()

        try realm.write {
            let bitcoin = PortfolioObject()
            bitcoin.coinID = "bitcoin"
            bitcoin.amount = 1.0
            realm.add(bitcoin)

            let ethereum = PortfolioObject()
            ethereum.coinID = "ethereum"
            ethereum.amount = 5.0
            realm.add(ethereum)
        }

        let results = realm.objects(PortfolioObject.self).sorted(byKeyPath: "coinID")
        XCTAssertEqual(results.count, 2)
        guard results.count == 2 else { return }
        XCTAssertEqual(results[0].coinID, "bitcoin")
        XCTAssertEqual(results[1].coinID, "ethereum")
    }
}

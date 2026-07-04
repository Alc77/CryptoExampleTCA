// CryptoExampleTCATests/Persistence/RealmControllerTests.swift
import RealmSwift
import Testing

extension BaseSuite {
    @Suite struct RealmControllerTests {

        @Test func portfolioItemRoundTrip() throws {
            let realm = try RealmController.inMemory(id: #function).realm()

            try realm.write {
                let obj = PortfolioObject()
                obj.coinID = "bitcoin"
                obj.amount = 1.5
                realm.add(obj)
            }

            let result = realm.objects(PortfolioObject.self).first
            #expect(result?.coinID == "bitcoin")
            #expect(result?.amount == 1.5)
        }

        @Test func multipleItemsRoundTrip() throws {
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
            try #require(results.count == 2)
            #expect(results[0].coinID == "bitcoin")
            #expect(results[1].coinID == "ethereum")
        }
    }
}

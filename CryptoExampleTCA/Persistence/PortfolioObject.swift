// CryptoExampleTCA/Persistence/PortfolioObject.swift
import RealmSwift

final class PortfolioObject: Object {
    @Persisted(primaryKey: true) var coinID: String = ""
    @Persisted var amount: Double = 0.0
}

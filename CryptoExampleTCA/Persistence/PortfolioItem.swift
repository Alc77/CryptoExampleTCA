// CryptoExampleTCA/Persistence/PortfolioItem.swift
import Foundation

struct PortfolioItem: Codable, Equatable, Sendable {
    var coinID: String
    var amount: Double
}

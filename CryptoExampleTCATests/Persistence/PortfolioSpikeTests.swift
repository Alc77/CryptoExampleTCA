// CryptoExampleTCATests/Persistence/PortfolioSpikeTests.swift
import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

// Spike-only reducer — NOT shipped to production
@Reducer
private struct PortfolioSpike {
    @ObservableState
    struct State: Equatable {
        @Shared(.portfolioItems) var items: [PortfolioItem] = []
    }

    enum Action {
        case addItem(coinID: String, amount: Double)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addItem(coinID, amount):
                state.$items.withLock { $0.append(PortfolioItem(coinID: coinID, amount: amount)) }
                return .none
            }
        }
    }
}

final class PortfolioSpikeTests: XCTestCase {

    @MainActor
    func testInMemorySubstitution() async {
        let store = TestStore(
            initialState: PortfolioSpike.State()
        ) {
            PortfolioSpike()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.addItem(coinID: "bitcoin", amount: 1.5)) {
            $0.$items.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.5)] }
        }
    }
}

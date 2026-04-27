import ComposableArchitecture
import XCTest
@testable import CryptoExampleTCA

final class PortfolioFeatureTests: XCTestCase {

    // MARK: - AC1: coinTapped selects coin and clears amount (new coin)

    @MainActor
    func testCoinTappedSelectsCoinAndClearsAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(coins: [Self.bitcoin, Self.ethereum])
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.coinTapped(Self.bitcoin)) {
            $0.selectedCoin = Self.bitcoin
            $0.amountText = ""
        }
    }

    // MARK: - AC1: coinTapped prefills existing holding

    @MainActor
    func testCoinTappedPrefillsExistingHolding() async {
        // Use a shared Realm id so the two stores observe the same @Shared(.portfolioItems) reference.
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            // Save store: seed portfolioItems with bitcoin 2.5. DismissEffect marks this store dismissed.
            let saveStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "2.5"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await saveStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 2.5)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await saveStore.finish()

            // Prefill store: portfolioItems is already [bitcoin 2.5] via the shared reference.
            let prefillStore = TestStore(
                initialState: PortfolioFeature.State(coins: [Self.bitcoin])
            ) {
                PortfolioFeature()
            }
            await prefillStore.send(.coinTapped(Self.bitcoin)) {
                $0.selectedCoin = Self.bitcoin
                $0.amountText = "2.5"
            }
        }
    }

    // MARK: - amountChanged updates text

    @MainActor
    func testAmountChangedUpdatesText() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(coins: [Self.bitcoin], selectedCoin: Self.bitcoin)
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.amountChanged("2.5")) {
            $0.amountText = "2.5"
        }
    }

    // MARK: - AC2: saveButtonTapped appends new holding

    @MainActor
    func testSaveButtonTappedAddsNewHolding() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "2.5"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveButtonTapped) {
            $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 2.5)] }
            $0.amountText = ""
            $0.selectedCoin = nil
        }
        await store.finish()
    }

    // MARK: - AC3: saveButtonTapped updates existing holding (no duplicate)

    @MainActor
    func testSaveButtonTappedUpdatesExistingHolding() async {
        // Use a shared Realm id so both stores observe the same @Shared(.portfolioItems) reference.
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            // First save: add bitcoin at 1.0
            let firstStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "1.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await firstStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await firstStore.finish()

            // Second save: update bitcoin to 5.0 — shared reference already has [bitcoin 1.0].
            // Reducer must find the existing entry and update in-place; count must stay 1 (AC3).
            let updateStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "5.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await updateStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 5.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await updateStore.finish()
        }
    }

    // MARK: - AC4: saveButtonTapped no-ops on invalid amount

    @MainActor
    func testSaveButtonTappedNoOpsOnInvalidAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "abc"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }

    // MARK: - 4.6: saveButtonTapped no-ops on astronomical amount (above 1e15)

    @MainActor
    func testSaveButtonTappedNoOpsOnAstronomicalAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "1e16"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }

    // MARK: - 4.6: saveButtonTapped no-ops on subnormal amount (below 1e-12)

    @MainActor
    func testSaveButtonTappedNoOpsOnSubnormalAmount() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "5e-324"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }

    // MARK: - 4.6: saveButtonTapped accepts the inclusive lower bound (1e-12)

    @MainActor
    func testSaveButtonTappedAcceptsExactLowerBound() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "1e-12"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveButtonTapped) {
            $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1e-12)] }
            $0.amountText = ""
            $0.selectedCoin = nil
        }
        await store.finish()
    }

    // MARK: - 4.6: saveButtonTapped accepts the inclusive upper bound (1e15)

    @MainActor
    func testSaveButtonTappedAcceptsExactUpperBound() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "1e15"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
            $0.dismiss = DismissEffect { }
        }

        await store.send(.saveButtonTapped) {
            $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1e15)] }
            $0.amountText = ""
            $0.selectedCoin = nil
        }
        await store.finish()
    }

    // MARK: - AC2 & AC6: saveButtonTapped removes existing holding on zero amount

    @MainActor
    func testSaveButtonTappedRemovesExistingHoldingOnZeroAmount() async {
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            let seedStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "1.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await seedStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await seedStore.finish()

            let removeStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await removeStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await removeStore.finish()
        }
    }

    // MARK: - AC1 & AC6: saveButtonTapped removes existing holding on empty amount

    @MainActor
    func testSaveButtonTappedRemovesExistingHoldingOnEmptyAmount() async {
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            let seedStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: "2.5"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await seedStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 2.5)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await seedStore.finish()

            let removeStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin],
                    selectedCoin: Self.bitcoin,
                    amountText: ""
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await removeStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await removeStore.finish()
        }
    }

    // MARK: - AC2 & AC6: saveButtonTapped removes only the targeted entry

    @MainActor
    func testSaveButtonTappedRemovesOnlyTargetEntry() async {
        await withDependencies {
            $0.realmController = .inMemory(id: UUID().uuidString)
        } operation: {
            let seedBitcoin = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin, Self.ethereum],
                    selectedCoin: Self.bitcoin,
                    amountText: "1.0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await seedBitcoin.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.0)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await seedBitcoin.finish()

            let seedEthereum = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin, Self.ethereum],
                    selectedCoin: Self.ethereum,
                    amountText: "2.5"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await seedEthereum.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock { $0 = [PortfolioItem(coinID: "bitcoin", amount: 1.0), PortfolioItem(coinID: "ethereum", amount: 2.5)] }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await seedEthereum.finish()

            let removeStore = TestStore(
                initialState: PortfolioFeature.State(
                    coins: [Self.bitcoin, Self.ethereum],
                    selectedCoin: Self.bitcoin,
                    amountText: "0"
                )
            ) {
                PortfolioFeature()
            } withDependencies: {
                $0.dismiss = DismissEffect { }
            }
            await removeStore.send(.saveButtonTapped) {
                $0.$portfolioItems.withLock {
                    $0 = [PortfolioItem(coinID: "ethereum", amount: 2.5)]
                }
                $0.amountText = ""
                $0.selectedCoin = nil
            }
            await removeStore.finish()
        }
    }

    // MARK: - AC4: saveButtonTapped no-ops on zero amount for a coin not in portfolio

    @MainActor
    func testSaveButtonTappedNoOpsOnZeroAmountForNewCoin() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: "0"
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }

    // MARK: - AC4: saveButtonTapped no-ops on empty amount for a coin not in portfolio

    @MainActor
    func testSaveButtonTappedNoOpsOnEmptyAmountForNewCoin() async {
        let store = TestStore(
            initialState: PortfolioFeature.State(
                coins: [Self.bitcoin],
                selectedCoin: Self.bitcoin,
                amountText: ""
            )
        ) {
            PortfolioFeature()
        } withDependencies: {
            $0.realmController = .inMemory(id: UUID().uuidString)
        }

        await store.send(.saveButtonTapped)
    }
}

// MARK: - Fixtures

// Canonical fixtures defined in `PortfolioFeatureFixtures.swift`.
// Sibling test files reference `PortfolioFeatureTests.bitcoin` / `.ethereum` directly.

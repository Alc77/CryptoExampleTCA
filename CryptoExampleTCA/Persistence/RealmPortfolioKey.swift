// CryptoExampleTCA/Persistence/RealmPortfolioKey.swift
import RealmSwift
import Dependencies
import Sharing

// MARK: - Ergonomic accessor

extension SharedReaderKey where Self == RealmPortfolioKey {
    static var portfolioItems: RealmPortfolioKey { RealmPortfolioKey() }
}

// MARK: - SharedKey conformance

struct RealmPortfolioKey: SharedKey, Hashable {
    typealias Value = [PortfolioItem]

    func load(
        context: LoadContext<[PortfolioItem]>,
        continuation: LoadContinuation<[PortfolioItem]>
    ) {
        @Dependency(\.realmController) var controller
        do {
            let realm = try controller.realm()
            let items = realm.objects(PortfolioObject.self).map {
                PortfolioItem(coinID: $0.coinID, amount: $0.amount)
            }
            continuation.resume(returning: Array(items))
        } catch {
            continuation.resumeReturningInitialValue()
        }
    }

    func subscribe(
        context: LoadContext<[PortfolioItem]>,
        subscriber: SharedSubscriber<[PortfolioItem]>
    ) -> SharedSubscription {
        @Dependency(\.realmController) var controller
        nonisolated(unsafe) var token: NotificationToken?
        do {
            let realm = try controller.realm()
            let results = realm.objects(PortfolioObject.self)
            token = results.observe { changes in
                // Skip `.initial` — load() already delivered the initial value synchronously,
                // and Realm's async .initial delivery would race with any withLock writes
                // that happen between subscribe() and the observer's first runloop pass.
                switch changes {
                case .initial:
                    break
                case .update(let objects, _, _, _):
                    let items = objects.map {
                        PortfolioItem(coinID: $0.coinID, amount: $0.amount)
                    }
                    subscriber.yield(Array(items))
                case .error:
                    break
                }
            }
        } catch {
            // Realm open failure — subscriber receives no updates; load() handles initial value
        }
        return SharedSubscription {
            token?.invalidate()
        }
    }

    func save(
        _ value: [PortfolioItem],
        context: SaveContext,
        continuation: SaveContinuation
    ) {
        @Dependency(\.realmController) var controller
        do {
            let realm = try controller.realm()
            try realm.write {
                realm.delete(realm.objects(PortfolioObject.self))
                for item in value {
                    let obj = PortfolioObject()
                    obj.coinID = item.coinID
                    obj.amount = item.amount
                    realm.add(obj, update: .modified)
                }
            }
        } catch {
            // Write failure — continuation still called so @Shared doesn't hang
        }
        continuation.resume()
    }
}

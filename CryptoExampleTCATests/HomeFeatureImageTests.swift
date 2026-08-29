import ComposableArchitecture
import Testing
import UIKit

extension BaseSuite {
    @MainActor
    @Suite struct HomeFeatureImageTests {

        @Test func loadImageFetchesAndStoresImage() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in stub }
            }

            await store.send(.loadImage(url))
            await store.receive(\.imageLoaded) {
                $0.images[url] = stub
            }
        }

        @Test func loadImageSkipsWhenAlreadyCached() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()
            let callCount = LockIsolated(0)

            var initial = HomeFeature.State()
            initial.images[url] = stub

            let store = TestStore(initialState: initial) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in callCount.withValue { $0 += 1 }; return stub }
            }

            await store.send(.loadImage(url))
            #expect(callCount.value == 0)
        }

        @Test func loadImageFailureLeavesStateUntouched() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in throw ImageCacheError.decodingFailed }
            }

            await store.send(.loadImage(url))
            await store.receive(\.imageLoaded)

            #expect(store.state.images.isEmpty)
            #expect(store.state.error == nil)
        }
    }
}

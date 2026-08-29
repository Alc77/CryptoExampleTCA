import ComposableArchitecture
import Testing
import UIKit

extension BaseSuite {
    @MainActor
    @Suite struct HomeFeatureImageTests {

        @Test func loadImageFetchesAndStoresImage() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()
            // Capture the argument, not just the count: a reducer that fetched a hardcoded or
            // wrong URL would still store `stub` under `url` and pass a count-only assertion.
            let requested = LockIsolated<[URL]>([])

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { requestedURL in
                    requested.withValue { $0.append(requestedURL) }
                    return stub
                }
            }

            await store.send(.loadImage(url))
            await store.receive(\.imageLoaded) {
                $0.images[url] = stub
            }
            #expect(requested.value == [url])
        }

        /// Two different coins must each fetch their own URL — pins the `url` threaded through
        /// `loadImage` → `imageCache.image` → `imageLoaded(url:)` against an off-by-one mix-up.
        @Test func loadImageRequestsTheURLItWasGiven() async throws {
            let btc = try #require(URL(string: "https://example.com/btc.png"))
            let eth = try #require(URL(string: "https://example.com/eth.png"))
            let btcImage = UIImage()
            let ethImage = UIImage()
            let requested = LockIsolated<[URL]>([])

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { requestedURL in
                    requested.withValue { $0.append(requestedURL) }
                    return requestedURL == btc ? btcImage : ethImage
                }
            }

            await store.send(.loadImage(btc))
            await store.receive(\.imageLoaded) {
                $0.images[btc] = btcImage
            }
            await store.send(.loadImage(eth))
            await store.receive(\.imageLoaded) {
                $0.images[eth] = ethImage
            }

            #expect(requested.value == [btc, eth])
        }

        /// Review patch: a relative `CoinModel.image` value such as CoinGecko's "missing_large.png"
        /// parses into a scheme-less URL that can only ever fail. It must never reach the client —
        /// otherwise it re-fetches on every `onAppear` forever, since failures are not recorded.
        @Test func loadImageIgnoresURLWithoutHTTPScheme() async throws {
            let relative = try #require(URL(string: "missing_large.png"))
            let callCount = LockIsolated(0)

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in
                    callCount.withValue { $0 += 1 }
                    return UIImage()
                }
            }

            await store.send(.loadImage(relative))

            #expect(callCount.value == 0)
            #expect(store.state.images.isEmpty)
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

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

            await store.send(.loadImage(url)) {
                $0.loadingImageURLs.insert(url)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(url)
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

            await store.send(.loadImage(btc)) {
                $0.loadingImageURLs.insert(btc)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(btc)
                $0.images[btc] = btcImage
            }
            await store.send(.loadImage(eth)) {
                $0.loadingImageURLs.insert(eth)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(eth)
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

        @Test func loadImageFailureMarksURLWithoutSettingError() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in throw ImageCacheError.decodingFailed }
            }

            await store.send(.loadImage(url)) {
                $0.loadingImageURLs.insert(url)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(url)
                $0.failedImageURLs.insert(url)
            }

            #expect(store.state.images.isEmpty)
            #expect(store.state.error == nil)
        }

        /// A failure for one coin must not affect any other coin's slot — `failedImageURLs` is
        /// keyed by `URL`, and `URL` equality is sensitive to paths, queries and encoding.
        @Test func loadImageFailureIsScopedToTheURLThatFailed() async throws {
            let btc = try #require(URL(string: "https://example.com/btc.png"))
            let eth = try #require(URL(string: "https://example.com/eth.png"))
            let ethImage = UIImage()

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { requestedURL in
                    guard requestedURL == eth else { throw ImageCacheError.decodingFailed }
                    return ethImage
                }
            }

            await store.send(.loadImage(btc)) {
                $0.loadingImageURLs.insert(btc)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(btc)
                $0.failedImageURLs.insert(btc)
            }

            await store.send(.loadImage(eth)) {
                $0.loadingImageURLs.insert(eth)
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(eth)
                $0.images[eth] = ethImage
            }

            #expect(store.state.failedImageURLs == [btc])
            #expect(store.state.images[eth] === ethImage)
            #expect(store.state.images[btc] == nil)
        }

        /// A row can re-appear (scroll, tab switch, re-sort) before its first load resolves.
        /// The second dispatch must be dropped rather than starting a duplicate fetch+decode.
        @Test func loadImageSkipsURLAlreadyInFlight() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()
            let callCount = LockIsolated(0)
            // Gate the stub on a TestClock so the first load is *deterministically* still in
            // flight when the second dispatch arrives — otherwise it may resolve in between and
            // the second dispatch gets guarded by `images[url]` instead, testing nothing.
            let clock = TestClock()

            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.imageCache.image = { _ in
                    callCount.withValue { $0 += 1 }
                    try await clock.sleep(for: .seconds(1))
                    return stub
                }
            }

            await store.send(.loadImage(url)) {
                $0.loadingImageURLs.insert(url)
            }
            await store.send(.loadImage(url))   // in flight → guarded, NO trailing closure

            await clock.advance(by: .seconds(1))
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(url)
                $0.images[url] = stub
            }
            #expect(callCount.value == 1)
        }

        /// A URL that failed and later succeeds must not stay marked failed — otherwise
        /// `images[url] != nil && failedImageURLs.contains(url)` is reachable and the
        /// "failed ⇒ no image" invariant is silently false.
        @Test func loadImageSuccessClearsAPriorFailureMark() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()

            var initial = HomeFeature.State()
            initial.failedImageURLs.insert(url)

            let store = TestStore(initialState: initial) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in stub }
            }

            // The failure mark is what `reloadButtonTapped` clears, so model that first.
            await store.send(.imageLoaded(url: url, result: .success(stub))) {
                $0.failedImageURLs.remove(url)
                $0.images[url] = stub
            }

            #expect(store.state.failedImageURLs.isEmpty)
        }

        @Test func loadImageSkipsURLThatAlreadyFailed() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let callCount = LockIsolated(0)

            var initial = HomeFeature.State()
            initial.failedImageURLs.insert(url)

            let store = TestStore(initialState: initial) {
                HomeFeature()
            } withDependencies: {
                $0.imageCache.image = { _ in callCount.withValue { $0 += 1 }; return UIImage() }
            }

            await store.send(.loadImage(url))   // guarded → no state change, NO trailing closure
            #expect(callCount.value == 0)
        }

        /// Review fix (D1): clearing `failedImageURLs` is not a retry on its own. `.onAppear`
        /// fires on row identity, which a refresh does not change, so a row already on screen
        /// would otherwise sit on a spinner with no request behind it. Reload must re-dispatch.
        @Test func reloadButtonTappedClearsAndRetriesFailedImageURLs() async throws {
            let url = try #require(URL(string: "https://example.com/btc.png"))
            let stub = UIImage()
            let requested = LockIsolated<[URL]>([])

            var initial = HomeFeature.State()
            initial.failedImageURLs.insert(url)

            let store = TestStore(initialState: initial) {
                HomeFeature()
            } withDependencies: {
                $0.hapticClient.impact = { }
                $0.coinGeckoClient.fetchCoins = { HomeFeatureTests.mockCoins }
                $0.coinGeckoClient.fetchMarketData = { HomeFeatureTests.mockMarketData }
                $0.imageCache.image = { requestedURL in
                    requested.withValue { $0.append(requestedURL) }
                    return stub
                }
            }

            await store.send(.reloadButtonTapped) {
                $0.isLoading = true
                $0.error = nil
                $0.failedImageURLs = []
            }

            await store.receive(\.loadImage) {
                $0.loadingImageURLs.insert(url)
            }
            await store.receive(\.coinsFetched.success) {
                $0.coins = HomeFeatureTests.mockCoins
            }
            await store.receive(\.marketDataFetched.success) {
                $0.statistics = HomeFeatureTests.mockMarketData.toStatistics()
                $0.isLoading = false
            }
            await store.receive(\.imageLoaded) {
                $0.loadingImageURLs.remove(url)
                $0.images[url] = stub
            }

            #expect(requested.value == [url])
        }
    }
}

import ComposableArchitecture
import SwiftUI

@main
struct CryptoExampleTCAApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    } withDependencies: {
        if let apiKey = Bundle.main.infoDictionary?["CoinGeckoAPIKey"] as? String,
           !apiKey.isEmpty,
           apiKey != "<placeholder>" {
            $0.httpClient = .live(apiKey: apiKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}

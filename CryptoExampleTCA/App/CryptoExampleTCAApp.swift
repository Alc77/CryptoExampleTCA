import ComposableArchitecture
import SwiftUI

@main
struct CryptoExampleTCAApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    } withDependencies: {
        if let rawKey = Bundle.main.infoDictionary?["CoinGeckoAPIKey"] as? String {
            // Strip angle brackets in case the key was entered as <CG-...> instead of CG-...
            let apiKey = rawKey.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            if !apiKey.isEmpty, apiKey != "placeholder" {
                $0.httpClient = .live(apiKey: apiKey)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}

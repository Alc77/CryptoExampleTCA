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
            // Skip the app UI when XCTest is running — otherwise HomeView.onAppear fires
            // and starts a coinGeckoClient fetch task (using the unimplemented testValue)
            // that races against the test suite.
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                AppView(store: store)
            }
        }
    }
}

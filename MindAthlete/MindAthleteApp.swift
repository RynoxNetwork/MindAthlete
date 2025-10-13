import SwiftUI

@main
struct MindAthleteApp: App {
    @StateObject private var appState = AppState(currentUser: .mock, hasCompletedOnboarding: true)
    private let environment = AppEnvironment.live()
    
    var body: some Scene {
        WindowGroup {
            RootView(appState: appState, environment: environment)
                .environmentObject(appState)
        }
    }
}

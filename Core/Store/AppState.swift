import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding: Bool = false

    init(currentUser: User? = nil, hasCompletedOnboarding: Bool = false) {
        self.currentUser = currentUser
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}


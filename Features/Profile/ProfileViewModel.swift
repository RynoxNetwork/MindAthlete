
import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User
    private let authService: AuthServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    init(user: User, authService: AuthServiceProtocol, analytics: AnalyticsServiceProtocol) {
        self.user = user
        self.authService = authService
        self.analytics = analytics
    }

    func signOut() async {
        do {
            try await authService.signOut()
            analytics.track(event: AnalyticsEvent(name: "sign_out", parameters: [:]))
        } catch {
            analytics.track(event: AnalyticsEvent(name: "sign_out_failed", parameters: ["error": error.localizedDescription]))
        }
    }
}

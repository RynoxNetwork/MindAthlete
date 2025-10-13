import Foundation

enum Logger {
    static func log(_ message: String) {
        #if DEBUG
        print("[MindAthlete] \(message)")
        #endif
    }
}

struct AppEnvironment {
    let authService: AuthServiceProtocol
    let databaseService: DatabaseServiceProtocol
    let aiService: AIServiceProtocol
    let purchaseService: PurchaseServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let notificationService: NotificationServiceProtocol

    static func live() -> AppEnvironment {
        AppEnvironment(
            authService: AuthService(),
            databaseService: DatabaseService(),
            aiService: AIService(),
            purchaseService: PurchaseService(),
            analyticsService: AnalyticsService(),
            notificationService: NotificationService()
        )
    }
}

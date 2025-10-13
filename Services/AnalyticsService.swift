
import Foundation

protocol AnalyticsServiceProtocol {
    func configure()
    func track(event: AnalyticsEvent)
}

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
}

final class AnalyticsService: AnalyticsServiceProtocol {
    func configure() {
        // Setup Firebase or TelemetryDeck
    }

    func track(event: AnalyticsEvent) {
        // Forward event to analytics provider
    }
}

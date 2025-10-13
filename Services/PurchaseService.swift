
import Foundation

protocol PurchaseServiceProtocol {
    func configure()
    func presentPaywall() async
    func refreshEntitlements() async
}

final class PurchaseService: PurchaseServiceProtocol {
    func configure() {
        // Initialize RevenueCat with API key.
    }

    func presentPaywall() async {
        // Show custom paywall when products are ready.
    }

    func refreshEntitlements() async {
        // Refresh RevenueCat entitlements.
    }
}

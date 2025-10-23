import Combine
import Foundation

@MainActor
final class TestsOverviewViewModel: ObservableObject {
    struct InstrumentRow: Identifiable {
        let instrument: AssessmentInstrument
        let iconName: String
        let title: String
        let description: String
        let estimatedDuration: String
        let statusText: String
        let ctaTitle: String
        let ctaEnabled: Bool
        let lockedUntil: Date?

        var id: AssessmentInstrument { instrument }
    }

    @Published private(set) var rows: [InstrumentRow] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var latestAssessments: [AssessmentInstrument: Date] = [:] {
        didSet { rebuildRows() }
    }
    private var subscriptionTier: SubscriptionTier = .free {
        didSet { rebuildRows() }
    }

    private let databaseService: SupabaseDatabaseService
    private let analytics: AnalyticsServiceProtocol
    private var hasTrackedOpen = false
    private let calendar = Calendar.current
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()

    init(databaseService: SupabaseDatabaseService, analytics: AnalyticsServiceProtocol) {
        self.databaseService = databaseService
        self.analytics = analytics
    }

    func load() async {
        guard !isLoading else { return }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            async let entitlementsTask = databaseService.listEntitlements()
            async let assessmentsTask = databaseService.listAssessments()

            let entitlements = try await entitlementsTask
            let assessments = try await assessmentsTask

            subscriptionTier = determineTier(from: entitlements)
            latestAssessments = mapLatestAssessments(from: assessments)

            trackOverviewOpenedIfNeeded()
        } catch {
            errorMessage = "No pudimos cargar tus autoevaluaciones. Intenta nuevamente."
            analytics.track(event: AnalyticsEvent(name: "tests_overview_load_failed", parameters: ["error": error.localizedDescription]))
        }

        isLoading = false
    }

    func refresh() async {
        hasTrackedOpen = false
        await load()
    }

    func lastTakenDate(for instrument: AssessmentInstrument) -> Date? {
        latestAssessments[instrument]
    }

    func status(for instrument: AssessmentInstrument) -> AssessmentStatus {
        AssessmentEligibility.status(
            for: instrument,
            lastTaken: latestAssessments[instrument],
            tier: subscriptionTier,
            referenceDate: Date(),
            calendar: calendar
        )
    }

    func trackStart(for instrument: AssessmentInstrument) {
        analytics.track(
            event: AnalyticsEvent(
                name: "test_started",
                parameters: [
                    "instrument": instrument.rawValue,
                    "tier": subscriptionTier.rawValue,
                    "last_taken": latestAssessments[instrument]?.timeIntervalSince1970 ?? 0
                ]
            )
        )
    }

    func trackCompletion(for instrument: AssessmentInstrument, wasRetake: Bool, takenAt: Date) {
        analytics.track(
            event: AnalyticsEvent(
                name: "test_completed",
                parameters: [
                    "instrument": instrument.rawValue,
                    "tier": subscriptionTier.rawValue,
                    "retake": wasRetake
                ]
            )
        )

        if wasRetake {
            analytics.track(
                event: AnalyticsEvent(
                    name: "test_retaken",
                    parameters: [
                        "instrument": instrument.rawValue,
                        "tier": subscriptionTier.rawValue,
                        "interval_days": latestAssessments[instrument].map { daysBetween($0, takenAt) } ?? 0
                    ]
                )
            )
        }

        latestAssessments[instrument] = takenAt
        trackOverviewOpenedIfNeeded(force: true)
    }

    func makeFlowViewModel(for instrument: AssessmentInstrument) -> TestFlowViewModel {
        TestFlowViewModel(
            instrument: instrument,
            databaseService: databaseService,
            analytics: analytics,
            subscriptionTier: subscriptionTier,
            lastTaken: latestAssessments[instrument]
        )
    }

    // MARK: - Private helpers

    private func rebuildRows() {
        rows = AssessmentInstrument.allCases.map { instrument in
            let status = status(for: instrument)
            let statusText: String
            let ctaTitle: String
            let enabled: Bool
            let lockedDate: Date?

            switch status {
            case .neverTaken:
                statusText = "Nunca realizado"
                ctaTitle = "Iniciar test"
                enabled = true
                lockedDate = nil
            case .available(let lastTaken):
                if let lastTaken {
                    statusText = "Última vez el \(dateFormatter.string(from: lastTaken))"
                    ctaTitle = "Repetir test"
                } else {
                    statusText = "Listo para comenzar"
                    ctaTitle = "Iniciar test"
                }
                enabled = true
                lockedDate = nil
            case .lockedUntil(let date):
                lockedDate = date
                statusText = lockedStatusText(until: date)
                ctaTitle = "Retomar"
                enabled = false
            }

            return InstrumentRow(
                instrument: instrument,
                iconName: instrument.iconName,
                title: instrument.title,
                description: instrument.description,
                estimatedDuration: instrument.estimatedDuration,
                statusText: statusText,
                ctaTitle: ctaTitle,
                ctaEnabled: enabled,
                lockedUntil: lockedDate
            )
        }
    }

    private func determineTier(from entitlements: [EntitlementRow]) -> SubscriptionTier {
        entitlements.first(where: { $0.active && $0.product.lowercased().contains("premium") }) != nil ? .premium : .free
    }

    private func mapLatestAssessments(from rows: [AssessmentRow]) -> [AssessmentInstrument: Date] {
        rows.reduce(into: [AssessmentInstrument: Date]()) { result, row in
            guard let instrument = AssessmentInstrument(rawValue: row.instrument) else { return }
            if let existing = result[instrument] {
                if row.taken_at > existing {
                    result[instrument] = row.taken_at
                }
            } else {
                result[instrument] = row.taken_at
            }
        }
    }

    private func lockedStatusText(until date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: Date()) {
            return "Disponible más tarde hoy"
        }

        let formatted = relativeFormatter.localizedString(for: date, relativeTo: Date())
        return "Retomar \(formatted)"
    }

    private func trackOverviewOpenedIfNeeded(force: Bool = false) {
        guard force || !hasTrackedOpen else { return }
        hasTrackedOpen = true
        let pending = AssessmentEligibility.pendingInstruments(
            latestAssessments: latestAssessments,
            tier: subscriptionTier,
            referenceDate: Date(),
            calendar: calendar
        )
        analytics.track(
            event: AnalyticsEvent(
                name: "tests_overview_opened",
                parameters: [
                    "tier": subscriptionTier.rawValue,
                    "pending": pending.count
                ]
            )
        )
    }

    private func daysBetween(_ earlier: Date, _ later: Date) -> Int {
        calendar.dateComponents([.day], from: earlier, to: later).day ?? 0
    }
}

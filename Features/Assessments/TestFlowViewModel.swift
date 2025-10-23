import Combine
import Foundation

@MainActor
final class TestFlowViewModel: ObservableObject {
    struct SubscaleResult: Identifiable {
        let id: String
        let title: String
        let normalized: Double
        let raw: Int
    }

    struct Summary {
        let instrument: AssessmentInstrument
        let takenAt: Date
        let wasRetake: Bool
        let subscales: [SubscaleResult]
        let overallScore: Double
    }

    let instrument: AssessmentInstrument
    let items: [AssessmentInstrument.Item]

    @Published private(set) var currentIndex: Int = 0
    @Published private var answers: [Int?]
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var summary: Summary?
    @Published var errorMessage: String?

    var progress: Double {
        Double(currentIndex + 1) / Double(items.count)
    }

    var currentItem: AssessmentInstrument.Item {
        items[currentIndex]
    }

    var canSubmit: Bool {
        answers.allSatisfy { $0 != nil } && !isSubmitting
    }

    private let databaseService: SupabaseDatabaseService
    private let analytics: AnalyticsServiceProtocol
    private let subscriptionTier: SubscriptionTier
    private let lastTaken: Date?

    init(instrument: AssessmentInstrument,
         databaseService: SupabaseDatabaseService,
         analytics: AnalyticsServiceProtocol,
         subscriptionTier: SubscriptionTier,
         lastTaken: Date?) {
        self.instrument = instrument
        self.databaseService = databaseService
        self.analytics = analytics
        self.subscriptionTier = subscriptionTier
        self.lastTaken = lastTaken
        self.items = instrument.items
        self.answers = Array(repeating: nil, count: instrument.items.count)
    }

    func select(answer: Int) {
        answers[currentIndex] = answer
    }

    func answer(for index: Int) -> Int? {
        guard answers.indices.contains(index) else { return nil }
        return answers[index]
    }

    func goNext() {
        guard currentIndex < items.count - 1 else { return }
        currentIndex += 1
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let scored = scoreAnswers()
            let assessmentRow = try await databaseService.createAssessment(
                instrument: instrument.rawValue,
                summary: scored.summaryPayload,
                items: scored.itemsPayload
            )

            summary = Summary(
                instrument: instrument,
                takenAt: assessmentRow.taken_at,
                wasRetake: lastTaken != nil,
                subscales: scored.subscales,
                overallScore: scored.overall
            )
        } catch {
            errorMessage = "No pudimos guardar tus respuestas. Intenta nuevamente."
            analytics.track(event: AnalyticsEvent(name: "test_submit_failed", parameters: ["instrument": instrument.rawValue, "error": error.localizedDescription]))
        }

        isSubmitting = false
    }

    // MARK: - Scoring helpers

    private func scoreAnswers() -> (subscales: [SubscaleResult], overall: Double, summaryPayload: [String: AnyCodable], itemsPayload: [AssessmentItemInput]) {
        let recordedAnswers = answers.enumerated().reduce(into: [String: [Int]]()) { partial, pair in
            let (index, value) = pair
            guard let rawValue = value else { return }
            let item = items[index]
            let scored = item.isReversed ? (6 - rawValue) : rawValue
            partial[item.subscaleId, default: []].append(scored)
        }

        var subscaleResults: [SubscaleResult] = []
        var summaryDict: [String: AnyCodable] = [:]
        var itemsPayload: [AssessmentItemInput] = []

        var overallAccumulator: Double = 0
        var overallCount: Int = 0

        for (subscaleId, scores) in recordedAnswers {
            let rawSum = scores.reduce(0, +)
            let minScore = scores.count * 1
            let maxScore = scores.count * 5
            let normalized = Double(rawSum - minScore) / Double(max(maxScore - minScore, 1)) * 100
            let subscaleMeta = instrument.subscales.first { $0.id == subscaleId }
            let title = subscaleMeta?.title ?? subscaleId.capitalized
            subscaleResults.append(
                SubscaleResult(
                    id: subscaleId,
                    title: title,
                    normalized: normalized,
                    raw: rawSum
                )
            )
            summaryDict[subscaleId] = AnyCodable([
                "normalized": AnyCodable(normalized),
                "raw": AnyCodable(rawSum)
            ])
            overallAccumulator += normalized
            overallCount += 1
        }

        let overallScore = overallCount > 0 ? overallAccumulator / Double(overallCount) : 0
        summaryDict["overall"] = AnyCodable(overallScore)
        summaryDict["tier"] = AnyCodable(subscriptionTier.rawValue)

        for (index, answer) in answers.enumerated() {
            guard let value = answer else { continue }
            let item = items[index]
            let scored = item.isReversed ? (6 - value) : value
            let normalized = Double(scored - 1) / 4 * 100
            let itemCode = "\(instrument.itemCodePrefix)_\(String(format: "%02d", index + 1))"
            itemsPayload.append(
                AssessmentItemInput(
                    subscale: item.subscaleId,
                    itemCode: itemCode,
                    raw: scored,
                    normalized: normalized
                )
            )
        }

        return (subscales: subscaleResults.sorted { $0.title < $1.title },
                overall: overallScore,
                summaryPayload: summaryDict,
                itemsPayload: itemsPayload)
    }
}

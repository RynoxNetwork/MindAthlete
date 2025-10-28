import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: ChatMessageRole
        var content: String
        var isStreaming: Bool
    }

    @Published private(set) var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var habitPlan: HabitPlanResponseDTO?
    @Published var isGeneratingPlan = false
    @Published var pendingEscalation = false
    @Published var escalationURL: URL?
    @Published var habitHint: String?

    private let userId: String
    private let aiService: AIServiceProtocol
    private let database: SupabaseDatabaseService
    private let analytics: AnalyticsServiceProtocol
    private var chatId: UUID?
    private var historyLoaded = false

    init(userId: String, aiService: AIServiceProtocol, database: SupabaseDatabaseService, analytics: AnalyticsServiceProtocol) {
        self.userId = userId
        self.aiService = aiService
        self.database = database
        self.analytics = analytics
    }

    func loadHistory() async {
        guard !historyLoaded else { return }
        historyLoaded = true
        do {
            if let latestChat = try await database.latestChat() {
                chatId = latestChat.id
                let rows = try await database.listChatMessages(chatId: latestChat.id)
                messages = rows.map { row in
                    Message(
                        id: row.id,
                        role: ChatMessageRole(rawValue: row.role) ?? .assistant,
                        content: row.content,
                        isStreaming: false
                    )
                }
            }
        } catch {
            errorMessage = "No pudimos cargar tu historial."
            analytics.track(event: AnalyticsEvent(name: "chat_history_failed", parameters: ["user_id": userId, "error": error.localizedDescription]))
        }
    }

    func sendCurrentMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""

        let userMessage = Message(id: UUID(), role: .user, content: trimmed, isStreaming: false)
        messages.append(userMessage)

        analytics.track(event: AnalyticsEvent(name: "chat_message_sent", parameters: ["user_id": userId]))
        streamReply()
    }

    private func streamReply() {
        isSending = true
        errorMessage = nil
        pendingEscalation = false
        escalationURL = nil
        let history = messages.map { ChatMessagePayload(role: $0.role, content: $0.content) }

        Task {
            do {
                var assistantMessageId: UUID?
                for try await event in aiService.chatStream(userId: userId, chatId: chatId, messages: history, tone: nil, targetGoal: nil) {
                    chatId = event.chatId

                    if let delta = event.delta, !delta.isEmpty {
                        if let id = assistantMessageId, let index = messages.firstIndex(where: { $0.id == id }) {
                            messages[index].content.append(delta)
                        } else {
                            let newId = UUID()
                            assistantMessageId = newId
                            messages.append(Message(id: newId, role: .assistant, content: delta, isStreaming: true))
                        }
                    }

                    if event.finished {
                        if let id = assistantMessageId, let index = messages.firstIndex(where: { $0.id == id }) {
                            messages[index].isStreaming = false
                        }
                        isSending = false
                        pendingEscalation = event.escalate ?? false
                        escalationURL = event.bookingURL
                        habitHint = event.habitHint
                        analytics.track(
                            event: AnalyticsEvent(
                                name: "chat_message_completed",
                                parameters: [
                                    "user_id": userId,
                                    "escalate": pendingEscalation,
                                    "habit_hint": habitHint ?? "none"
                                ]
                            )
                        )
                    }
                }
            } catch {
                isSending = false
                errorMessage = "No pudimos enviar el mensaje. Intenta de nuevo."
                analytics.track(
                    event: AnalyticsEvent(
                        name: "chat_message_failed",
                        parameters: ["user_id": userId, "error": error.localizedDescription]
                    )
                )
            }
        }
    }

    func generateHabitPlan() async {
        guard !isGeneratingPlan else { return }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        do {
            let context = habitHint != nil ? ["hint": habitHint!] : nil
            let plan = try await aiService.generateHabitPlan(for: userId, timeframe: "next 7 days", context: context)
            try await persistHabits(from: plan)
            habitPlan = plan
            habitHint = nil
            analytics.track(
                event: AnalyticsEvent(
                    name: "habit_plan_generated",
                    parameters: [
                        "user_id": userId,
                        "habits": plan.habits.count
                    ]
                )
            )
        } catch {
            errorMessage = "No pudimos generar el plan. Intenta más tarde."
            analytics.track(
                event: AnalyticsEvent(
                    name: "habit_plan_failed",
                    parameters: ["user_id": userId, "error": error.localizedDescription]
                )
            )
        }
    }

    private func persistHabits(from plan: HabitPlanResponseDTO) async throws {
        var existing = try await database.listHabits()
        let formatter = ISO8601DateFormatter()

        for item in plan.habits {
            if existing.contains(where: { $0.name.caseInsensitiveCompare(item.title) == .orderedSame }) {
                continue
            }
            let habit = try await database.createHabit(name: item.title, description: item.rationale)
            existing.append(habit)
            if let start = item.recommendedStartDate {
                try await database.logHabit(
                    habitId: habit.id,
                    adherence: nil,
                    notes: "plan_generated:\(formatter.string(from: start))"
                )
            }
        }
    }

    func escalate() async -> EscalationResponseDTO? {
        defer { pendingEscalation = false }
        do {
            let response = try await aiService.escalate(for: userId, context: ["source": "chat"], reason: "chat_flag")
            analytics.track(
                event: AnalyticsEvent(
                    name: "escalation_requested",
                    parameters: [
                        "source": "chat",
                        "escalate": response.escalate
                    ]
                )
            )
            return response
        } catch {
            errorMessage = "No pudimos iniciar la derivación. Intenta más tarde."
            analytics.track(
                event: AnalyticsEvent(
                    name: "escalation_failed",
                    parameters: ["source": "chat", "error": error.localizedDescription]
                )
            )
            return nil
        }
    }
}

@MainActor
final class CoachAIViewModel: ObservableObject {
    @Published var dailyTip: DailyRecommendationResponseDTO?
    @Published var isLoading = false

    let chatViewModel: ChatViewModel

    private let aiService: AIServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let userId: String

    init(userId: String, aiService: AIServiceProtocol, analytics: AnalyticsServiceProtocol, database: SupabaseDatabaseService? = nil) {
        self.userId = userId
        self.aiService = aiService
        self.analytics = analytics
        let database = database ?? SupabaseDatabaseService()
        self.chatViewModel = ChatViewModel(userId: userId, aiService: aiService, database: database, analytics: analytics)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let tip = try await aiService.dailyRecommendation(for: userId, date: Date())
            dailyTip = tip
            analytics.track(
                event: AnalyticsEvent(
                    name: "coach_daily_tip_loaded",
                    parameters: [
                        "model": tip.modelVersion,
                        "escalate": tip.escalate
                    ]
                )
            )
        } catch {
            analytics.track(
                event: AnalyticsEvent(
                    name: "coach_daily_tip_failed",
                    parameters: ["error": error.localizedDescription]
                )
            )
        }
    }

    func trackChatCTA() {
        analytics.track(
            event: AnalyticsEvent(
                name: "coach_daily_tip_chat_cta",
                parameters: ["user_id": userId]
            )
        )
    }

    func escalateFromDailyTip() async -> EscalationResponseDTO? {
        guard let tip = dailyTip else { return nil }
        do {
            let response = try await aiService.escalate(
                for: userId,
                context: [
                    "source": "coach_daily_tip",
                    "model": tip.modelVersion
                ],
                reason: "coach_daily_tip"
            )
            analytics.track(
                event: AnalyticsEvent(
                    name: "coach_daily_tip_escalation",
                    parameters: [
                        "escalate": response.escalate,
                        "booking_url": response.bookingURL?.absoluteString ?? "none"
                    ]
                )
            )
            return response
        } catch {
            analytics.track(
                event: AnalyticsEvent(
                    name: "coach_daily_tip_escalation_failed",
                    parameters: ["error": error.localizedDescription]
                )
            )
            return nil
        }
    }
}

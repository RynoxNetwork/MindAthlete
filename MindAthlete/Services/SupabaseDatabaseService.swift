import Foundation
import Supabase

struct MoodRow: Codable {
  let id: Int64?
  let user_id: UUID
  let mood: Int
  let energy: Int?
  let stress: Int?
  let focus: Int?
  let trigger: String?
  let sleep_hours: Double?
  let sleep_quality: Int?
  let notes: String?
  let created_at: Date?
}

struct InterventionPreferenceRow: Codable {
  let id: UUID
  let user_id: UUID
  let modality: String?
  let preferred_slots: [Int32]?
  let max_suggestions_per_day: Int16
  let do_not_disturb_hours: [Int32]?
  let tone: String?
  let created_at: Date?
}

struct EventRow: Codable {
  let id: UUID
  let user_id: UUID
  let title: String
  let kind: String?
  let starts_at: Date
  let ends_at: Date?
  let notes: String?
  let frequency: String?
  let repeat_days: [String]?
  let end_date: Date?
  let override_parent_id: UUID?
  let is_override: Bool?
  let created_at: Date?
}

struct HabitRow: Codable {
  let id: UUID
  let user_id: UUID
  let name: String
  let description: String?
  let active: Bool
  let created_at: Date?
}

struct ExternalCalendarRow: Codable {
  let id: UUID
  let user_id: UUID
  let provider: String
  let account_email: String?
  let sync_enabled: Bool
  let last_sync_at: Date?
  let created_at: Date?
}

struct AvailabilityBlockRow: Codable {
  let id: UUID
  let user_id: UUID
  let start_at: Date
  let end_at: Date
  let source: String
  let created_at: Date?
}

struct ChatRow: Codable {
  let id: UUID
  let user_id: UUID
  let title: String?
  let last_message_at: Date?
  let message_count: Int?
  let is_active: Bool?
  let created_at: Date?
  let updated_at: Date?
}

struct ChatMessageRow: Codable {
  let id: UUID
  let chat_id: UUID
  let user_id: UUID
  let role: String
  let content: String
  let metadata: [String: AnyCodable]?
  let created_at: Date
}

struct SleepPrefsRow: Codable {
  let user_id: UUID
  let target_wake_time: String?
  let cycles: Int?
  let buffer_minutes: Int?
  let updated_at: Date?
}

struct HabitLogRow: Codable {
  let id: UUID
  let habit_id: UUID
  let performed_at: Date
  let adherence: Int?
  let notes: String?
}

struct SessionRow: Codable {
  let id: UUID
  let slug: String
  let title: String
  let duration_sec: Int
  let modality: String
  let context_tags: [String]?
  let premium: Bool
  let content: [String: AnyCodable]
  let created_at: Date?
}

struct SessionMetricRow: Codable {
  let id: UUID
  let user_id: UUID
  let session_id: UUID
  let started_at: Date
  let pre_stress: Int?
  let pre_focus: Int?
  let finished_at: Date?
  let post_stress: Int?
  let post_focus: Int?
  let delta_stress: Int?
  let delta_focus: Int?
}

struct AssessmentRow: Codable {
  let id: UUID
  let user_id: UUID
  let instrument: String
  let taken_at: Date
  let summary: [String: AnyCodable]?
}

struct AssessmentItemRow: Codable {
  let id: UUID
  let assessment_id: UUID
  let subscale: String
  let item_code: String?
  let raw: Int
  let normalized: Double?
}

struct RecommendationRow: Codable {
  let id: UUID
  let user_id: UUID
  let context: String?
  let reason: [String: AnyCodable]?
  let session_id: UUID?
  let habit_id: UUID?
  let message: String?
  let created_at: Date?
}

struct CoachPolicyRow: Codable {
  let id: UUID
  let user_id: UUID
  let max_suggestions_per_day: Int?
  let priority_policy: String?
  let route_context: [String: AnyCodable]
  let poms_thresholds: [String: AnyCodable]?
  let conflict_policy: String?
  let durations: [String: AnyCodable]?
  let escalation_threshold: [String: AnyCodable]?
  let created_at: Date?
}

struct EntitlementRow: Codable {
  let id: UUID
  let user_id: UUID
  let product: String
  let active: Bool
  let source: String?
  let updated_at: Date?
}

struct DailyActionInput {
  let user_id: UUID
  let action_date: Date
  let code: String
  let title: String
  let source: String
  let is_checked: Bool?
}

@MainActor
final class SupabaseDatabaseService {
  private let client = MAClients.shared
  private lazy var isoDateTimeFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  func currentUserId() async throws -> UUID {
    let session = try await client.auth.session
    return session.user.id
  }

  func addMood(mood: Int, energy: Int, stress: Int, notes: String?) async throws {
    let session = try await client.auth.session
    let user = session.user

    let payload = [
      "user_id": AnyCodable(user.id),
      "mood": AnyCodable(mood),
      "energy": AnyCodable(energy),
      "stress": AnyCodable(stress),
      "notes": AnyCodable(notes)
    ]

    _ = try await client.database
      .from("moods")
      .insert(payload, returning: .minimal)
      .execute()
  }

  func fetchMoods() async throws -> [MoodRow] {
    let response: PostgrestResponse<[MoodRow]> = try await client.database
      .from("moods")
      .select()
      .order("created_at", ascending: false)
      .execute()
    return response.value
  }

  func getInterventionPrefs() async throws -> InterventionPreferenceRow? {
    let response: PostgrestResponse<[InterventionPreferenceRow]> = try await client.database
      .from("intervention_prefs")
      .select()
      .limit(1)
      .execute()
    return response.value.first
  }

  func upsertInterventionPrefs(modality: String?, tone: String?) async throws {
    let session = try await client.auth.session
    let payload = [
      "user_id": AnyCodable(session.user.id),
      "modality": AnyCodable(modality),
      "tone": AnyCodable(tone)
    ]
    _ = try await client.database
      .from("intervention_prefs")
      .upsert(payload, onConflict: "user_id", returning: .minimal)
      .execute()
  }

  func createEvent(
    title: String,
    kind: String?,
    startsAt: Date,
    endsAt: Date?,
    notes: String?,
    frequency: String?,
    repeatDays: [String]?,
    endDate: Date?,
    overrideParentId: UUID?,
    isOverride: Bool
  ) async throws -> EventRow {
    let session = try await client.auth.session
    let payload = EventInsert(
      user_id: session.user.id,
      title: title,
      kind: kind,
      starts_at: startsAt,
      ends_at: endsAt,
      notes: notes,
      frequency: frequency ?? "none",
      repeat_days: repeatDays,
      end_date: endDate,
      override_parent_id: overrideParentId,
      is_override: isOverride
    )
    let response: PostgrestResponse<[EventRow]> = try await client.database
      .from("events")
      .insert(payload)
      .select()
      .execute()
    guard let event = response.value.first else {
      throw NSError(domain: "Events", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el evento"])
    }
    return event
  }

  func listEvents() async throws -> [EventRow] {
    let response: PostgrestResponse<[EventRow]> = try await client.database
      .from("events")
      .select()
      .order("starts_at", ascending: true)
      .execute()
    return response.value
  }

  func createEvents(_ inserts: [EventInsert]) async throws -> [EventRow] {
    guard !inserts.isEmpty else { return [] }
    let response: PostgrestResponse<[EventRow]> = try await client.database
      .from("events")
      .insert(inserts)
      .select()
      .execute()
    return response.value
  }

  func createHabit(name: String, description: String?) async throws -> HabitRow {
    let session = try await client.auth.session
    let payload = HabitInsert(user_id: session.user.id, name: name, description: description)
    let response: PostgrestResponse<[HabitRow]> = try await client.database
      .from("habits")
      .insert(payload)
      .select()
      .execute()
    guard let habit = response.value.first else {
      throw NSError(domain: "Habits", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el hábito"])
    }
    return habit
  }

  func listHabits() async throws -> [HabitRow] {
    let response: PostgrestResponse<[HabitRow]> = try await client.database
      .from("habits")
      .select()
      .order("created_at", ascending: false)
      .execute()
    return response.value
  }

  func logHabit(habitId: UUID, adherence: Int?, notes: String?) async throws -> HabitLogRow {
    let payload = HabitLogInsert(habit_id: habitId, adherence: adherence, notes: notes)
    let response: PostgrestResponse<[HabitLogRow]> = try await client.database
      .from("habit_logs")
      .insert(payload)
      .select()
      .execute()
    guard let log = response.value.first else {
      throw NSError(domain: "HabitLogs", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo registrar el hábito"])
    }
    return log
  }

  func listHabitLogs(for habitId: UUID? = nil) async throws -> [HabitLogRow] {
    if let habitId {
      let response: PostgrestResponse<[HabitLogRow]> = try await client.database
        .from("habit_logs")
        .select()
        .eq("habit_id", value: habitId)
        .order("performed_at", ascending: false)
        .execute()
      return response.value
    } else {
      let response: PostgrestResponse<[HabitLogRow]> = try await client.database
        .from("habit_logs")
        .select()
        .order("performed_at", ascending: false)
        .execute()
      return response.value
    }
  }

  func listSessions() async throws -> [SessionRow] {
    let response: PostgrestResponse<[SessionRow]> = try await client.database
      .from("sessions")
      .select()
      .order("created_at", ascending: false)
      .execute()
    return response.value
  }

  func recordSessionMetric(sessionId: UUID, preStress: Int?, preFocus: Int?, postStress: Int?, postFocus: Int?) async throws -> SessionMetricRow {
    let session = try await client.auth.session
    let payload = SessionMetricInsert(
      user_id: session.user.id,
      session_id: sessionId,
      pre_stress: preStress,
      pre_focus: preFocus,
      post_stress: postStress,
      post_focus: postFocus
    )
    let response: PostgrestResponse<[SessionMetricRow]> = try await client.database
      .from("session_metrics")
      .insert(payload)
      .select()
      .execute()
    guard let metric = response.value.first else {
      throw NSError(domain: "SessionMetrics", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo registrar la sesión"])
    }
    return metric
  }

  func listSessionMetrics() async throws -> [SessionMetricRow] {
    let response: PostgrestResponse<[SessionMetricRow]> = try await client.database
      .from("session_metrics")
      .select()
      .order("started_at", ascending: false)
      .execute()
    return response.value
  }

  func createAssessment(instrument: String, summary: [String: AnyCodable]?, items: [AssessmentItemInput]) async throws -> AssessmentRow {
    let session = try await client.auth.session
    let assessmentPayload = AssessmentInsert(user_id: session.user.id, instrument: instrument, summary: summary)
    let assessmentResponse: PostgrestResponse<[AssessmentRow]> = try await client.database
      .from("assessments")
      .insert(assessmentPayload)
      .select()
      .execute()
    guard let assessment = assessmentResponse.value.first else {
      throw NSError(domain: "Assessments", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear el assessment"])
    }

    if !items.isEmpty {
      let itemPayloads = items.map { AssessmentItemInsert(assessment_id: assessment.id, subscale: $0.subscale, item_code: $0.itemCode, raw: $0.raw, normalized: $0.normalized) }
      _ = try await client.database
        .from("assessment_items")
        .insert(itemPayloads, returning: .minimal)
        .execute()
    }

    return assessment
  }

  func listAssessments() async throws -> [AssessmentRow] {
    let response: PostgrestResponse<[AssessmentRow]> = try await client.database
      .from("assessments")
      .select()
      .order("taken_at", ascending: false)
      .execute()
    return response.value
  }

  func createRecommendation(context: String?, message: String?, reason: [String: AnyCodable]?, sessionId: UUID?, habitId: UUID?) async throws -> RecommendationRow {
    let session = try await client.auth.session
    let payload = RecommendationInsert(
      user_id: session.user.id,
      context: context,
      reason: reason,
      session_id: sessionId,
      habit_id: habitId,
      message: message
    )
    let response: PostgrestResponse<[RecommendationRow]> = try await client.database
      .from("recommendations")
      .insert(payload)
      .select()
      .execute()
    guard let rec = response.value.first else {
      throw NSError(domain: "Recommendations", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la recomendación"])
    }
    return rec
  }

  func listRecommendations() async throws -> [RecommendationRow] {
    let response: PostgrestResponse<[RecommendationRow]> = try await client.database
      .from("recommendations")
      .select()
      .order("created_at", ascending: false)
      .execute()
    return response.value
  }

  func latestChat() async throws -> ChatRow? {
    let response: PostgrestResponse<[ChatRow]> = try await client.database
      .from("chats")
      .select()
      .order("updated_at", ascending: false)
      .limit(1)
      .execute()
    return response.value.first
  }

  func listChatMessages(chatId: UUID, limit: Int = 100) async throws -> [ChatMessageRow] {
    let response: PostgrestResponse<[ChatMessageRow]> = try await client.database
      .from("chat_messages")
      .select()
      .eq("chat_id", value: chatId)
      .order("created_at", ascending: true)
      .limit(limit)
      .execute()
    return response.value
  }

  func upsertCoachPolicy(routeContext: [String: AnyCodable], maxSuggestions: Int?, priority: String?) async throws -> CoachPolicyRow {
    let session = try await client.auth.session
    let payload = CoachPolicyInsert(
      user_id: session.user.id,
      max_suggestions_per_day: maxSuggestions,
      priority_policy: priority,
      route_context: routeContext
    )
    let response: PostgrestResponse<[CoachPolicyRow]> = try await client.database
      .from("coach_policies")
      .upsert(payload, onConflict: "user_id")
      .select()
      .execute()
    guard let policy = response.value.first else {
      throw NSError(domain: "CoachPolicies", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo actualizar la política"] )
    }
    return policy
  }

  func listEntitlements() async throws -> [EntitlementRow] {
    let response: PostgrestResponse<[EntitlementRow]> = try await client.database
      .from("entitlements")
      .select()
      .execute()
    return response.value
  }
  func listExternalCalendars() async throws -> [ExternalCalendarRow] {
    let response: PostgrestResponse<[ExternalCalendarRow]> = try await client.database
      .from("external_calendars")
      .select()
      .execute()
    return response.value
  }

  func upsertExternalCalendar(provider: String, accountEmail: String?, syncEnabled: Bool) async throws -> ExternalCalendarRow {
    let session = try await client.auth.session
    let payload = ExternalCalendarInsert(user_id: session.user.id, provider: provider, account_email: accountEmail, sync_enabled: syncEnabled)
    let response: PostgrestResponse<[ExternalCalendarRow]> = try await client.database
      .from("external_calendars")
      .upsert(payload, onConflict: "user_id,provider")
      .select()
      .execute()
    guard let calendar = response.value.first else {
      throw NSError(domain: "ExternalCalendars", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo guardar el calendario externo"])
    }
    return calendar
  }

  func deleteExternalCalendar(id: UUID) async throws {
    _ = try await client.database
      .from("external_calendars")
      .delete()
      .eq("id", value: id)
      .execute()
  }

  func upsertAvailabilityBlocks(_ blocks: [AvailabilityBlockInsert]) async throws {
    guard !blocks.isEmpty else { return }
    _ = try await client.database
      .from("availability_blocks")
      .upsert(blocks, returning: .minimal)
      .execute()
  }

  func listAvailabilityBlocks(range: ClosedRange<Date>? = nil) async throws -> [AvailabilityBlockRow] {
    var request = client.database
      .from("availability_blocks")
      .select()

    if let range {
      let startISO = isoDateTimeFormatter.string(from: range.lowerBound)
      let endISO = isoDateTimeFormatter.string(from: range.upperBound)
      request = request
        .gte("start_at", value: startISO)
        .lte("end_at", value: endISO)
    }

    let response: PostgrestResponse<[AvailabilityBlockRow]> = try await request
      .order("start_at", ascending: true)
      .execute()
    return response.value
  }

  func getSleepPreferences() async throws -> SleepPrefsRow? {
    let session = try await client.auth.session
    let response: PostgrestResponse<[SleepPrefsRow]> = try await client.database
      .from("sleep_prefs")
      .select()
      .eq("user_id", value: session.user.id)
      .limit(1)
      .execute()
    return response.value.first
  }

  func upsertSleepPreferences(targetWakeTime: String?, cycles: Int?, buffer: Int?) async throws -> SleepPrefsRow {
    let session = try await client.auth.session
    let payload = SleepPrefsInsert(user_id: session.user.id, target_wake_time: targetWakeTime, cycles: cycles, buffer_minutes: buffer)
    let response: PostgrestResponse<[SleepPrefsRow]> = try await client.database
      .from("sleep_prefs")
      .upsert(payload, returning: .representation)
      .execute()
    guard let prefs = response.value.first else {
      throw NSError(domain: "SleepPrefs", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudieron guardar las preferencias de sueño"])
    }
    return prefs
  }

  func addJournalEntry(date: Date, body: String, tags: [String]?, sentiment: Int?, intent: [String: AnyCodable]?) async throws -> JournalEntryRow {
    let session = try await client.auth.session
    let payload = JournalEntryInsert(user_id: session.user.id, entry_date: date, body: body, tags: tags, sentiment: sentiment, intent: intent)
    let response: PostgrestResponse<[JournalEntryRow]> = try await client.database
      .from("journal_entries")
      .insert(payload)
      .select()
      .execute()
    guard let entry = response.value.first else {
      throw NSError(domain: "Journal", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo guardar el diario"])
    }
    return entry
  }

  func listJournalEntries(limit: Int = 20) async throws -> [JournalEntryRow] {
    let response: PostgrestResponse<[JournalEntryRow]> = try await client.database
      .from("journal_entries")
      .select()
      .order("created_at", ascending: false)
      .limit(limit)
      .execute()
    return response.value
  }

  func upsertDailyActions(_ actions: [DailyActionInput]) async throws {
    guard !actions.isEmpty else { return }
    let payload = actions.map {
      DailyActionInsert(
        user_id: $0.user_id,
        action_date: $0.action_date,
        code: $0.code,
        title: $0.title,
        source: $0.source,
        is_checked: $0.is_checked
      )
    }
    _ = try await client.database
      .from("daily_actions")
      .upsert(payload, returning: .minimal)
      .execute()
  }

  func listDailyActions(for date: Date) async throws -> [DailyActionRow] {
    let response: PostgrestResponse<[DailyActionRow]> = try await client.database
      .from("daily_actions")
      .select()
      .eq("action_date", value: dateFormatter.string(from: date))
      .order("created_at", ascending: true)
      .execute()
    return response.value
  }

  func toggleDailyAction(id: UUID, checked: Bool) async throws {
    _ = try await client.database
      .from("daily_actions")
      .update(["is_checked": AnyCodable(checked)])
      .eq("id", value: id)
      .execute()
  }

  private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .init(secondsFromGMT: 0)
    return formatter
  }
}

// MARK: - Insert payloads

struct EventInsert: Encodable {
  let user_id: UUID
  let title: String
  let kind: String?
  let starts_at: Date
  let ends_at: Date?
  let notes: String?
  let frequency: String?
  let repeat_days: [String]?
  let end_date: Date?
  let override_parent_id: UUID?
  let is_override: Bool?
}

struct HabitInsert: Encodable {
  let user_id: UUID
  let name: String
  let description: String?
}

struct HabitLogInsert: Encodable {
  let habit_id: UUID
  let adherence: Int?
  let notes: String?
}

struct SessionMetricInsert: Encodable {
  let user_id: UUID
  let session_id: UUID
  let pre_stress: Int?
  let pre_focus: Int?
  let post_stress: Int?
  let post_focus: Int?
}

struct AssessmentInsert: Encodable {
  let user_id: UUID
  let instrument: String
  let summary: [String: AnyCodable]?
}

struct AssessmentItemInsert: Encodable {
  let assessment_id: UUID
  let subscale: String
  let item_code: String?
  let raw: Int
  let normalized: Double?
}

struct RecommendationInsert: Encodable {
  let user_id: UUID
  let context: String?
  let reason: [String: AnyCodable]?
  let session_id: UUID?
  let habit_id: UUID?
  let message: String?
}

struct CoachPolicyInsert: Encodable {
  let user_id: UUID
  let max_suggestions_per_day: Int?
  let priority_policy: String?
  let route_context: [String: AnyCodable]
}

struct ExternalCalendarInsert: Encodable {
  let user_id: UUID
  let provider: String
  let account_email: String?
  let sync_enabled: Bool
}

struct AvailabilityBlockInsert: Encodable {
  let user_id: UUID
  let start_at: Date
  let end_at: Date
  let source: String
}

struct SleepPrefsInsert: Encodable {
  let user_id: UUID
  let target_wake_time: String?
  let cycles: Int?
  let buffer_minutes: Int?
}

struct JournalEntryInsert: Encodable {
  let user_id: UUID
  let entry_date: Date
  let body: String
  let tags: [String]?
  let sentiment: Int?
  let intent: [String: AnyCodable]?
}

struct DailyActionInsert: Encodable {
  let user_id: UUID
  let action_date: Date
  let code: String
  let title: String
  let source: String
  let is_checked: Bool?
}

struct AssessmentItemInput {
  let subscale: String
  let itemCode: String?
  let raw: Int
  let normalized: Double?
}

// MARK: - AnyCodable helper

struct AnyCodable: Codable {
  private let value: Any

  init<T>(_ value: T?) {
    self.value = value ?? ()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case is Void:
      try container.encodeNil()
    case let v as Bool:
      try container.encode(v)
    case let v as Int:
      try container.encode(v)
    case let v as Int8:
      try container.encode(v)
    case let v as Int16:
      try container.encode(v)
    case let v as Int32:
      try container.encode(v)
    case let v as Int64:
      try container.encode(v)
    case let v as UInt:
      try container.encode(v)
    case let v as UInt8:
      try container.encode(v)
    case let v as UInt16:
      try container.encode(v)
    case let v as UInt32:
      try container.encode(v)
    case let v as UInt64:
      try container.encode(v)
    case let v as Double:
      try container.encode(v)
    case let v as Float:
      try container.encode(v)
    case let v as String:
      try container.encode(v)
    case let v as Date:
      try container.encode(v)
    case let v as UUID:
      try container.encode(v)
    case let v as [AnyCodable]:
      try container.encode(v)
    case let v as [String: AnyCodable]:
      try container.encode(v)
    default:
      let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Valor no codificable \(value)")
      throw EncodingError.invalidValue(value, context)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self.value = ()
    } else if let v = try? container.decode(Bool.self) {
      self.value = v
    } else if let v = try? container.decode(Int.self) {
      self.value = v
    } else if let v = try? container.decode(Double.self) {
      self.value = v
    } else if let v = try? container.decode(String.self) {
      self.value = v
    } else if let v = try? container.decode([String: AnyCodable].self) {
      self.value = v
    } else if let v = try? container.decode([AnyCodable].self) {
      self.value = v
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Tipo no soportado")
    }
  }
}
struct JournalEntryRow: Codable {
  let id: UUID
  let user_id: UUID
  let entry_date: Date
  let body: String
  let tags: [String]?
  let sentiment: Int?
  let intent: [String: AnyCodable]?
  let created_at: Date?
}

struct DailyActionRow: Codable {
  let id: UUID
  let user_id: UUID
  let action_date: Date
  let code: String
  let title: String
  let source: String
  let is_checked: Bool
  let created_at: Date?
}

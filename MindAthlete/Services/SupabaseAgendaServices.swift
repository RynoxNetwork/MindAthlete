import Foundation

final class SupabaseCalendarService: CalendarService {
  private let db = SupabaseDatabaseService()

  func linkGoogleAccount() async throws {
    throw NSError(domain: "Calendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Integración Google pendiente."])
  }

  func linkNotionAccount() async throws {
    throw NSError(domain: "Calendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Integración Notion pendiente."])
  }

  func syncExternalCalendars() async throws {
    // Placeholder: edge function should pull events from Google/Notion
    _ = try await db.listExternalCalendars()
  }

  func createLocalEvent(_ event: AgendaEvent) async throws -> AgendaEvent {
    let row = try await db.createEvent(
      title: event.title,
      kind: event.kind,
      startsAt: event.start,
      endsAt: event.end,
      notes: event.notes,
      frequency: event.recurrence?.frequency.rawValue ?? "none",
      repeatDays: event.recurrence?.repeatDays,
      endDate: event.recurrence?.endDate,
      overrideParentId: event.overrideParentId,
      isOverride: event.isOverride
    )
    return mapRow(row, source: "local")
  }

  func createEventOccurrences(for masterId: UUID, occurrences: [AgendaEvent]) async throws -> [AgendaEvent] {
    guard !occurrences.isEmpty else { return [] }
    let sessionUser = try await db.currentUserId()
    let inserts = occurrences.map { occurrence -> EventInsert in
      EventInsert(
        user_id: sessionUser,
        title: occurrence.title,
        kind: occurrence.kind,
        starts_at: occurrence.start,
        ends_at: occurrence.end,
        notes: occurrence.notes,
        frequency: "none",
        repeat_days: [],
        end_date: nil,
        override_parent_id: masterId,
        is_override: occurrence.isOverride
      )
    }
    let rows = try await db.createEvents(inserts)
    return rows.map { mapRow($0, source: "local") }
  }

  func listEvents(from: Date, to: Date) async throws -> [AgendaEvent] {
    let local = try await db.listEvents().filter { $0.starts_at >= from && $0.starts_at <= to }
    // External calendars se normalizarán en el futuro.
    return local.map { mapRow($0, source: "local") }
  }

  func computeAvailability(from: Date, to: Date, minBlock: TimeInterval) async throws -> [TimeIntervalBlock] {
    let events = try await listEvents(from: from, to: to)
    let availability = computeFreeBusy(events: events, dayBounds: (from, to))
    return availability.filter { $0.duration >= minBlock }
  }

  private func mapRow(_ row: EventRow, source: String) -> AgendaEvent {
    let recurrence: AgendaRecurrence?
    if let frequencyRaw = row.frequency, let frequency = AgendaRecurrenceFrequency(rawValue: frequencyRaw), frequency != .none {
      recurrence = AgendaRecurrence(
        frequency: frequency,
        repeatDays: row.repeat_days ?? [],
        endDate: row.end_date
      )
    } else {
      recurrence = nil
    }
    return AgendaEvent(
      id: row.id,
      title: row.title,
      start: row.starts_at,
      end: row.ends_at ?? row.starts_at.addingTimeInterval(3600),
      kind: row.kind,
      notes: row.notes,
      source: source,
      recurrence: recurrence,
      overrideParentId: row.override_parent_id,
      isOverride: row.is_override ?? false
    )
  }
}

extension SupabaseCalendarService: AvailabilityService {
  func computeFreeBusy(events: [AgendaEvent], dayBounds: (Date, Date)) -> [TimeIntervalBlock] {
    let sorted = events.sorted { $0.start < $1.start }
    var cursor = dayBounds.0
    var free: [TimeIntervalBlock] = []

    for event in sorted {
      if event.start > cursor {
        free.append(TimeIntervalBlock(start: cursor, end: event.start))
      }
      cursor = max(cursor, event.end)
    }

    if cursor < dayBounds.1 {
      free.append(TimeIntervalBlock(start: cursor, end: dayBounds.1))
    }

    return free.filter { $0.duration >= 15 * 60 }
  }

  func proposeSleepWindow(day: Date, prefs: SleepPrefs) -> SleepPlan {
    let calendar = Calendar.current
    var comps = prefs.targetWakeTime ?? calendar.dateComponents([.hour, .minute], from: Date())
    comps.year = calendar.component(.year, from: day)
    comps.month = calendar.component(.month, from: day)
    comps.day = calendar.component(.day, from: day) + 1
    let wake = calendar.date(from: comps) ?? day.addingTimeInterval(24 * 3600)
    let total = TimeInterval(prefs.cycles) * 90 * 60 + TimeInterval(prefs.bufferMinutes) * 60
    let start = wake.addingTimeInterval(-total)
    return SleepPlan(start: start, end: wake, cycles: prefs.cycles)
  }

  func proposeMindfulnessSlots(free: [TimeIntervalBlock], context: CoachContext) -> [SuggestionSlot] {
    var res: [SuggestionSlot] = []
    if let competition = context.todayEvents.first(where: { $0.kind == "competencia" }) {
      res.append(SuggestionSlot(at: competition.start.addingTimeInterval(-20 * 60), protocolId: "box_breathing", duration: 180))
    }
    for training in context.todayEvents where training.kind == "entreno" {
      res.append(SuggestionSlot(at: training.end.addingTimeInterval(10 * 60), protocolId: "body_scan_light", duration: 180))
    }
    if (context.energy ?? 10) <= 4, let block = free.first(where: { $0.duration >= 15 * 60 }) {
      res.append(SuggestionSlot(at: block.start.addingTimeInterval(5 * 60), protocolId: "micro_reset_90s", duration: 90))
    }
    return res
  }
}

final class SupabaseJournalService: JournalService {
  private let db = SupabaseDatabaseService()

  func addEntry(date: Date, body: String) async throws -> JournalEntry {
    let signals = extractSignals(body)
    let row = try await db.addJournalEntry(date: date, body: body, tags: signals.tags, sentiment: signals.sentiment, intent: signals.intent)
    return JournalEntry(id: row.id, date: row.entry_date, body: row.body, tags: row.tags ?? [], sentiment: row.sentiment, intent: row.intent)
  }

  func suggestPrompts(context: CoachContext) -> [String] {
    var prompts: [String] = [
      "¿Qué fue lo más desafiante de hoy y cómo respondiste?",
      "Completa: “Me siento ___ porque ___; para mañana haré ___”."
    ]
    if context.todayEvents.contains(where: { $0.kind == "competencia" }) {
      prompts.append("Antes de la competencia: ¿qué señal de calma usarás (respiración, palabra ancla)?")
    }
    return Array(prompts.prefix(3))
  }

  func extractSignals(_ body: String) -> JournalSignals {
    let lower = body.lowercased()
    var tags: [String] = []
    if lower.contains("ansios") || lower.contains("nerv") { tags.append("ansiedad") }
    if lower.contains("competencia") || lower.contains("torneo") { tags.append("competencia") }
    var sentiment = 0
    if lower.contains("preocup") { sentiment -= 2 }
    if lower.contains("motivad") || lower.contains("confianz") { sentiment += 2 }
    let intent = parseGoal(from: lower)
    return JournalSignals(tags: tags, sentiment: sentiment, intent: intent)
  }

  func listEntries(limit: Int) async throws -> [JournalEntry] {
    let rows = try await db.listJournalEntries(limit: limit)
    return rows.map { JournalEntry(id: $0.id, date: $0.entry_date, body: $0.body, tags: $0.tags ?? [], sentiment: $0.sentiment, intent: $0.intent) }
  }

  private func parseGoal(from text: String) -> [String: AnyCodable]? {
    guard let range = text.range(of: "sudamerican") else { return nil }
    let start = text.distance(from: text.startIndex, to: range.lowerBound)
    return ["goal": AnyCodable("sudamericano"), "position": AnyCodable(start)]
  }
}

final class SupabaseDailyActionsService: DailyActionsService {
  private let db = SupabaseDatabaseService()

  func upsertActions(for date: Date, from recommendations: [RecommendationRow]) async throws {
    let userId = try await db.currentUserId()
    let inserts = recommendations.map {
      DailyActionInput(
        user_id: userId,
        action_date: date,
        code: "reco_\($0.id.uuidString.prefix(6))",
        title: $0.message ?? "Acción recomendada",
        source: "ai",
        is_checked: nil
      )
    }
    try await db.upsertDailyActions(inserts)
  }

  func listActions(for date: Date) async throws -> [DailyAction] {
    let rows = try await db.listDailyActions(for: date)
    return rows.map {
      DailyAction(
        id: $0.id,
        date: $0.action_date,
        code: $0.code,
        title: $0.title,
        source: $0.source,
        isChecked: $0.is_checked
      )
    }
  }

  func toggleAction(id: UUID, checked: Bool) async throws {
    try await db.toggleDailyAction(id: id, checked: checked)
  }
}

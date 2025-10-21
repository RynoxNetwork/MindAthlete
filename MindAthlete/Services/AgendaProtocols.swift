import Foundation

struct TimeIntervalBlock: Equatable {
  let start: Date
  let end: Date

  var duration: TimeInterval {
    end.timeIntervalSince(start)
  }
}

struct SleepPrefs: Equatable {
  var targetWakeTime: DateComponents?
  var cycles: Int
  var bufferMinutes: Int
}

struct SleepPlan: Equatable {
  let start: Date
  let end: Date
  let cycles: Int
}

struct SuggestionSlot: Equatable {
  let at: Date
  let protocolId: String
  let duration: TimeInterval
}

struct JournalEntry {
  let id: UUID
  let date: Date
  let body: String
  let tags: [String]
  let sentiment: Int?
  let intent: [String: AnyCodable]?
}

struct JournalSignals {
  let tags: [String]
  let sentiment: Int?
  let intent: [String: AnyCodable]?
}

struct DailyAction: Identifiable {
  let id: UUID
  let date: Date
  let code: String
  let title: String
  let source: String
  var isChecked: Bool
}

struct AgendaEvent {
  let id: UUID
  let title: String
  let start: Date
  let end: Date
  let kind: String?
  let notes: String?
  let source: String
}

struct POMSResult {
  let completedAt: Date
  let tension: Int
  let vigor: Int
  let fatigue: Int
  let otherScores: [String: Int]
}

struct IDEPResult {
  let completedAt: Date
  let score: Int
}

struct Goal {
  let title: String
  let eventDate: Date?
}

struct CoachContext {
  let todayEvents: [AgendaEvent]
  let freeBlocks: [TimeIntervalBlock]
  let latestPOMS: POMSResult?
  let idep: IDEPResult?
  let sleepPrefs: SleepPrefs?
  let energy: Int?
  let stress: Int?
  let upcomingGoal: Goal?
}

protocol CalendarService {
  func linkGoogleAccount() async throws
  func linkNotionAccount() async throws
  func syncExternalCalendars() async throws
  func createLocalEvent(_ event: AgendaEvent) async throws -> AgendaEvent
  func listEvents(from: Date, to: Date) async throws -> [AgendaEvent]
  func computeAvailability(from: Date, to: Date, minBlock: TimeInterval) async throws -> [TimeIntervalBlock]
}

protocol AvailabilityService {
  func computeFreeBusy(events: [AgendaEvent], dayBounds: (Date, Date)) -> [TimeIntervalBlock]
  func proposeSleepWindow(day: Date, prefs: SleepPrefs) -> SleepPlan
  func proposeMindfulnessSlots(free: [TimeIntervalBlock], context: CoachContext) -> [SuggestionSlot]
}

protocol JournalService {
  func addEntry(date: Date, body: String) async throws -> JournalEntry
  func suggestPrompts(context: CoachContext) -> [String]
  func extractSignals(_ body: String) -> JournalSignals
  func listEntries(limit: Int) async throws -> [JournalEntry]
}

protocol DailyActionsService {
  func upsertActions(for date: Date, from recommendations: [RecommendationRow]) async throws
  func listActions(for date: Date) async throws -> [DailyAction]
  func toggleAction(id: UUID, checked: Bool) async throws
}

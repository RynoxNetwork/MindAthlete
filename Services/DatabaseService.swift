import Foundation

protocol DatabaseServiceProtocol {
    func fetchMoods(for userId: String) async throws -> [Mood]
    func saveMood(_ mood: Mood) async throws
    func fetchHabits(for userId: String) async throws -> [Habit]
    func saveHabit(_ habit: Habit) async throws
    func fetchEvents(for userId: String) async throws -> [Event]
    func saveEvent(_ event: Event) async throws
}

final class DatabaseService: DatabaseServiceProtocol {
    func fetchMoods(for userId: String) async throws -> [Mood] {
        []
    }

    func saveMood(_ mood: Mood) async throws {
        // Persist mood via Supabase RPC or table insert
    }

    func fetchHabits(for userId: String) async throws -> [Habit] {
        []
    }

    func saveHabit(_ habit: Habit) async throws {
        // Persist habit via Supabase
    }

    func fetchEvents(for userId: String) async throws -> [Event] {
        []
    }

    func saveEvent(_ event: Event) async throws {
        // Persist event via Supabase
    }
}

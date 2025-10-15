import Foundation
import Supabase

struct MoodRow: Codable {
  let id: Int64?
  let user_id: UUID
  let mood: Int
  let energy: Int
  let stress: Int
  let notes: String?
  let created_at: String?
}

@MainActor
final class SupabaseDatabaseService {
  private let client = MAClients.shared

  func addMood(mood: Int, energy: Int, stress: Int, notes: String?) async throws {
    let session = try await client.auth.session
    let user = session.user

    let input = MoodRow(
      id: nil,
      user_id: user.id,
      mood: mood,
      energy: energy,
      stress: stress,
      notes: notes,
      created_at: nil
    )

    _ = try await client.database
      .from("moods")
      .insert(input)
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
}

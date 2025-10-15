import Combine
import Foundation
import Supabase

@MainActor
final class SupabaseAuthService: ObservableObject {
  private let client = MAClients.shared
  @Published private(set) var supaUser: Supabase.User?

  func signUp(email: String, password: String) async throws {
    let response = try await client.auth.signUp(email: email, password: password)
    supaUser = try await resolveUser(from: response.user)
  }

  func signIn(email: String, password: String) async throws {
    let response = try await client.auth.signIn(email: email, password: password)
    supaUser = try await resolveUser(from: response.user)
  }

  func signOut() async throws {
    try await client.auth.signOut()
    supaUser = nil
  }

  private func resolveUser(from user: Supabase.User?) async throws -> Supabase.User? {
    if let user {
      return user
    }

    let session = try await client.auth.session
    return session.user
  }
}

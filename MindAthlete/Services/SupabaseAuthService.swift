import Combine
import Foundation
import Supabase

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class SupabaseAuthService: ObservableObject {
  private let client = MAClients.shared

  @Published private(set) var session: Supabase.Session?
  @Published private(set) var supaUser: Supabase.User?
  @Published var passwordRecoveryPending: Bool = false

  init() {
    Task { await startAuthListener() }
  }

  // MARK: - Public API

  func signUp(email: String, password: String) async throws {
    try await client.auth.signUp(email: email, password: password)
    await refreshSession()
  }

  func signIn(email: String, password: String) async throws {
    try await client.auth.signIn(email: email, password: password)
    await refreshSession()
  }

  func signOut() async {
    do {
      try await client.auth.signOut()
    } catch {
      Logger.log("Supabase signOut error: \(error.localizedDescription)")
    }
    clearSession()
  }

  func resetPassword(email: String, redirectTo: URL) async throws {
    try await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo)
  }

#if canImport(GoogleSignIn)
  func signInWithGoogle(idToken: String, accessToken: String) async throws {
    try await client.auth.signInWithIdToken(
      credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
    )
    await refreshSession()
  }
#endif

  var isAuthenticated: Bool { session != nil }
  var currentUserId: UUID? { supaUser?.id }
  var user: Supabase.User? { supaUser }

  // MARK: - Internal helpers

  func updatePassword(to newPassword: String) async throws {
    try await client.auth.update(user: UserAttributes(password: newPassword))
    passwordRecoveryPending = false
    await refreshSession()
  }

  private func startAuthListener() async {
    for await (event, session) in client.auth.authStateChanges {
      handle(event: event, session: session)
    }
  }

  private func handle(event: Supabase.AuthChangeEvent, session: Supabase.Session?) {
    switch event {
    case .initialSession:
      updateSession(session)
    case .signedIn,
         .userUpdated,
         .passwordRecovery,
         .tokenRefreshed:
      updateSession(session)
      if event == .passwordRecovery {
        passwordRecoveryPending = true
      }
    case .signedOut,
         .userDeleted:
      clearSession()
    @unknown default:
      Logger.log("Unhandled auth change event: \(String(describing: event))")
    }
  }

  private func refreshSession() async {
    do {
      let session = try await client.auth.session
      updateSession(session)
    } catch {
      Logger.log("Supabase session refresh failed: \(error.localizedDescription)")
      clearSession()
    }
  }

  private func updateSession(_ session: Supabase.Session?) {
    self.session = session
    self.supaUser = session?.user
  }

  private func clearSession() {
    session = nil
    supaUser = nil
    passwordRecoveryPending = false
  }
}

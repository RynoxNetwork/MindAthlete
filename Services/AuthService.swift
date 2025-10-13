
import Foundation

protocol AuthServiceProtocol {
    var currentUser: User? { get }
    func configure() async
    func signIn(email: String, password: String) async throws -> User
    func signInWithApple(token: String) async throws -> User
    func signOut() async throws
}

final class AuthService: AuthServiceProtocol {
    private(set) var currentUser: User?

    func configure() async {
        // Setup Supabase client with environment variables.
    }

    func signIn(email: String, password: String) async throws -> User {
        // Replace with Supabase auth implementation.
        let user = User(id: UUID().uuidString, email: email, sport: nil, university: nil, consent: false, createdAt: Date())
        currentUser = user
        return user
    }

    func signInWithApple(token: String) async throws -> User {
        let user = User(id: UUID().uuidString, email: "apple@mindathlete.app", sport: nil, university: nil, consent: false, createdAt: Date())
        currentUser = user
        return user
    }

    func signOut() async throws {
        currentUser = nil
    }
}

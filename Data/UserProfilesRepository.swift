import Foundation
import Supabase

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let user_id: UUID
    var email: String
    var display_name: String?
    var university: String?
    var consent: Bool
    var created_at: Date
    var updated_at: Date
}

@MainActor
final class UserProfilesRepository {
    private let client = MAClients.shared

    func getMyProfile() async throws -> UserProfile? {
        let session = try await client.auth.session
        let uid = session.user.id
        let response: PostgrestResponse<[UserProfile]> = try await client.database
            .from("user_profiles")
            .select()
            .eq("id", value: uid)
            .limit(1)
            .execute()
        return response.value.first
    }

    func upsertMyProfile(email: String) async throws {
        let session = try await client.auth.session
        let uid = session.user.id
        let payload = UserProfileUpsertPayload(user_id: uid, email: email)
        _ = try await client.database
            .from("user_profiles")
            .upsert(payload, onConflict: "user_id", returning: .minimal)
            .execute()
    }

    func updateConsent(_ consent: Bool) async throws {
        let session = try await client.auth.session
        let uid = session.user.id
        _ = try await client.database
            .from("user_profiles")
            .update(["consent": consent])
            .eq("id", value: uid)
            .execute()
    }
}

private struct UserProfileUpsertPayload: Encodable {
    let user_id: UUID
    let email: String
}

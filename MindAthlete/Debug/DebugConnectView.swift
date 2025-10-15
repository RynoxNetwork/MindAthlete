import Supabase
import SwiftUI

struct DebugConnectView: View {
  @State private var status = "Idle"
  @StateObject private var auth = SupabaseAuthService()
  private let db = SupabaseDatabaseService()

  var body: some View {
    NavigationView {
      VStack(spacing: 14) {
        Text(status)
          .font(.callout)
          .multilineTextAlignment(.center)
          .padding(.vertical, 4)

        Button("Sign Up (test user)") {
          Task {
            do {
              try await auth.signUp(email: "test+1@mindathlete.app", password: "Test1234!")
              status = "Signed up ✅"
            } catch { status = "SignUp error: \(error.localizedDescription)" }
          }
        }
        .buttonStyle(.borderedProminent)

        Button("Sign In") {
          Task {
            do {
              try await auth.signIn(email: "test+1@mindathlete.app", password: "Test1234!")
              status = "Signed in ✅ user: \(auth.supaUser?.id.uuidString ?? "-")"
            } catch { status = "SignIn error: \(error.localizedDescription)" }
          }
        }
        .buttonStyle(.bordered)

        Button("Insert Mood") {
          Task {
            do {
              try await db.addMood(mood: 4, energy: 3, stress: 2, notes: "Primer insert 🎉")
              status = "Inserted mood ✅"
            } catch { status = "Insert error: \(error.localizedDescription)" }
          }
        }

        Button("Fetch Moods") {
          Task {
            do {
              let rows = try await db.fetchMoods()
              status = "Fetched \(rows.count) rows ✅"
            } catch { status = "Fetch error: \(error.localizedDescription)" }
          }
        }
      }
      .padding()
      .navigationTitle("Supabase Check")
    }
  }
}

#if DEBUG
#Preview {
  DebugConnectView()
}
#endif

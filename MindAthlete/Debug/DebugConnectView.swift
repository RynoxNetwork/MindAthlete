import Supabase
import SwiftUI

struct DebugConnectView: View {
  @State private var status = "Idle"
  @StateObject private var auth = SupabaseAuthService()
  private let db = SupabaseDatabaseService()
  @State private var lastHabitId: UUID?
  @State private var lastSessionId: UUID?

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

        Divider().padding(.vertical, 8)

        Button("Upsert Prefs (texto)") {
          Task {
            do {
              try await db.upsertInterventionPrefs(modality: "texto", tone: "empatico")
              status = "Prefs upsert ✅"
            } catch { status = "Prefs error: \(error.localizedDescription)" }
          }
        }

        Button("Create Habit") {
          Task {
            do {
              let habit = try await db.createHabit(name: "Respiración 2'", description: "Respira profundo 2 minutos")
              lastHabitId = habit.id
              status = "Habit \(habit.name) ✅"
            } catch { status = "Habit error: \(error.localizedDescription)" }
          }
        }

        Button("Log Habit") {
          Task {
            guard let habitId = lastHabitId else {
              status = "Crea un hábito primero"
              return
            }
            do {
              let log = try await db.logHabit(habitId: habitId, adherence: 80, notes: "Sesión matutina")
              status = "Habit log \(log.id) ✅"
            } catch { status = "Habit log error: \(error.localizedDescription)" }
          }
        }

        Button("List Habits") {
          Task {
            do {
              let habits = try await db.listHabits()
              status = "Habits \(habits.count) ✅"
            } catch { status = "List habits error: \(error.localizedDescription)" }
          }
        }

        Divider().padding(.vertical, 8)

        Button("List Sessions") {
          Task {
            do {
              let sessions = try await db.listSessions()
              lastSessionId = sessions.first?.id
              status = "Sessions \(sessions.count) ✅"
            } catch { status = "Sessions error: \(error.localizedDescription)" }
          }
        }

        Button("Record Session Metric") {
          Task {
            guard let sessionId = lastSessionId else {
              status = "Obtén sesiones primero"
              return
            }
            do {
              let metric = try await db.recordSessionMetric(sessionId: sessionId, preStress: 6, preFocus: 4, postStress: 3, postFocus: 7)
              status = "Session metric \(metric.id) ✅"
            } catch { status = "Metric error: \(error.localizedDescription)" }
          }
        }

        Button("List Metrics") {
          Task {
            do {
              let metrics = try await db.listSessionMetrics()
              status = "Metrics \(metrics.count) ✅"
            } catch { status = "Metrics error: \(error.localizedDescription)" }
          }
        }

        Divider().padding(.vertical, 8)

        Button("Create Event") {
          Task {
            do {
              let event = try await db.createEvent(
                title: "Entrenamiento",
                kind: "entreno",
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                notes: "Gimnasio",
                frequency: "none",
                repeatDays: [],
                endDate: nil,
                overrideParentId: nil,
                isOverride: false
              )
              status = "Event \(event.title) ✅"
            } catch { status = "Event error: \(error.localizedDescription)" }
          }
        }

        Button("List Events") {
          Task {
            do {
              let events = try await db.listEvents()
              status = "Events \(events.count) ✅"
            } catch { status = "Events error: \(error.localizedDescription)" }
          }
        }

        Divider().padding(.vertical, 8)

        Button("Create Recommendation") {
          Task {
            do {
              let rec = try await db.createRecommendation(context: "pre_comp", message: "Respira 2 minutos antes de competir", reason: ["source": AnyCodable("debug")], sessionId: lastSessionId, habitId: lastHabitId)
              status = "Recommendation \(rec.id) ✅"
            } catch { status = "Recommendation error: \(error.localizedDescription)" }
          }
        }

        Button("List Recommendations") {
          Task {
            do {
              let recs = try await db.listRecommendations()
              status = "Recommendations \(recs.count) ✅"
            } catch { status = "List recs error: \(error.localizedDescription)" }
          }
        }

        Button("List Assessments") {
          Task {
            do {
              let assessments = try await db.listAssessments()
              status = "Assessments \(assessments.count) ✅"
            } catch { status = "List assessments error: \(error.localizedDescription)" }
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Sign Out") {
            Task {
              do {
                try await auth.signOut()
                status = "Signed out ✅"
              } catch { status = "SignOut error: \(error.localizedDescription)" }
            }
          }
        }
      }
      .padding()
      .navigationTitle("Supabase Check")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#if DEBUG
#Preview {
  DebugConnectView()
}
#endif

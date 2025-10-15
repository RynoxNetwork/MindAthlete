import SwiftUI

struct RootView: View {
    @ObservedObject var appState: AppState
    let environment: AppEnvironment

    var body: some View {
        Group {
            if let _ = appState.currentUser, appState.hasCompletedOnboarding {
                mainTabView
            } else if appState.hasCompletedOnboarding {
                SupabaseEmailAuthView { user in
                    appState.currentUser = user
                    environment.analyticsService.track(
                        event: AnalyticsEvent(
                            name: "auth_success",
                            parameters: ["provider": "supabase_email"]
                        )
                    )
                }
            } else {
                OnboardingView(viewModel: OnboardingViewModel(authService: environment.authService, analytics: environment.analyticsService)) {
                    Task {
                        await environment.authService.configure()
                        appState.hasCompletedOnboarding = true
                    }
                }
            }
        }
        .onAppear {
            environment.analyticsService.configure()
            environment.purchaseService.configure()
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView(viewModel: HomeViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                aiService: environment.aiService,
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Inicio", systemImage: "house.fill") }

            DiaryView(viewModel: DiaryViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Diario", systemImage: "book.fill") }

            HabitsView(viewModel: HabitsViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Hábitos", systemImage: "checkmark.circle.fill") }

            SessionsView(viewModel: SessionsViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Sesiones", systemImage: "waveform") }

            CoachAIView(viewModel: CoachAIViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                aiService: environment.aiService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Coach", systemImage: "sparkles") }

            CalendarView(viewModel: CalendarViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Calendario", systemImage: "calendar") }

            if let user = appState.currentUser {
                ProfileView(viewModel: ProfileViewModel(user: user, authService: environment.authService, analytics: environment.analyticsService))
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            }
        }
        .tint(MAColorPalette.primary)
    }
}

#Preview {
    RootView(appState: AppState(currentUser: .mock, hasCompletedOnboarding: true), environment: .live())
}

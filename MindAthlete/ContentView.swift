import Supabase
import SwiftUI

struct RootView: View {
    @ObservedObject var appState: AppState
    let environment: AppEnvironment
    @StateObject private var supabaseAuth = SupabaseAuthService()
    private let profilesRepository = UserProfilesRepository()
    @State private var gateState: GateState = .loading
    @State private var isShowingNewPasswordSheet = false

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                authFlow
            } else {
                OnboardingView(viewModel: OnboardingViewModel(authService: environment.authService, analytics: environment.analyticsService)) {
                    Task {
                        await environment.authService.configure()
                        appState.hasCompletedOnboarding = true
                        await refreshGateState()
                    }
                }
            }
        }
        .onAppear {
            environment.analyticsService.configure()
            environment.purchaseService.configure()
            Task { await refreshGateState() }
        }
        .onChange(of: appState.hasCompletedOnboarding) { completed in
            if completed {
                Task { await refreshGateState() }
            } else {
                appState.currentUser = nil
                gateState = .needsAuth
            }
        }
        .onChange(of: supabaseAuth.isAuthenticated) { _ in
            Task { await refreshGateState() }
        }
        .onChange(of: supabaseAuth.passwordRecoveryPending) { pending in
            isShowingNewPasswordSheet = pending
        }
        .onChange(of: appState.currentUser) { newValue in
            if newValue == nil, case .ready = gateState {
                Task {
                    await supabaseAuth.signOut()
                    gateState = .needsAuth
                }
            }
        }
        .sheet(isPresented: $isShowingNewPasswordSheet) {
            NewPasswordView(auth: supabaseAuth) {
                isShowingNewPasswordSheet = false
                Task { await refreshGateState() }
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView(viewModel: HomeViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                userName: appState.currentUser?.email,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Inicio", systemImage: "house.fill") }

            SessionsView(viewModel: SessionsViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Sesiones", systemImage: "waveform.path.ecg") }

            ScheduleTabView(
                viewModel: AgendaViewModel(
                    userId: appState.currentUser?.id ?? "mock-user",
                    calendarService: SupabaseCalendarService(),
                    database: SupabaseDatabaseService(),
                    aiService: environment.aiService,
                    analytics: environment.analyticsService,
                    notificationService: environment.notificationService,
                    colorStore: AgendaColorStore()
                )
            )
                .tabItem { Label("Agenda", systemImage: "calendar") }

            HabitsView(viewModel: HabitsViewModel(
                userId: appState.currentUser?.id ?? "mock-user",
                database: environment.databaseService,
                analytics: environment.analyticsService
            ))
            .tabItem { Label("Hábitos", systemImage: "checkmark.circle") }

            NavigationStack {
                List {
                    NavigationLink {
                        CoachAIView(viewModel: CoachAIViewModel(
                            userId: appState.currentUser?.id ?? "mock-user",
                            aiService: environment.aiService,
                            analytics: environment.analyticsService
                        ))
                    } label: {
                        Label("Coach", systemImage: "sparkles")
                    }

                    NavigationLink {
                        CalendarView(viewModel: CalendarViewModel(
                            userId: appState.currentUser?.id ?? "mock-user",
                            database: environment.databaseService,
                            analytics: environment.analyticsService
                        ))
                    } label: {
                        Label("Calendario", systemImage: "calendar")
                    }

                    NavigationLink {
                        TestsOverviewStandaloneContainer(analytics: environment.analyticsService)
                    } label: {
                        Label("Autoevaluaciones", systemImage: "chart.bar.doc.horizontal")
                    }

                    if let user = appState.currentUser {
                        NavigationLink {
                            ProfileView(
                                viewModel: ProfileViewModel(
                                    user: user,
                                    authService: environment.authService,
                                    analytics: environment.analyticsService
                                ),
                                onSignOut: {
                                    Task {
                                        await supabaseAuth.signOut()
                                        appState.currentUser = nil
                                        gateState = .needsAuth
                                    }
                                }
                            )
                        } label: {
                            Label("Perfil", systemImage: "person.crop.circle")
                        }
                    }
                }
                .navigationTitle("More")
            }
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .tint(MAColorPalette.primary)
    }

    private enum GateState: Equatable {
        case loading
        case needsAuth
        case needsConsent(UserProfile)
        case ready(UserProfile)
        case error(String)
    }

    @ViewBuilder
    private var authFlow: some View {
        switch gateState {
        case .loading:
            ProgressView("Cargando sesión…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsAuth:
            SupabaseEmailAuthView(supaAuth: supabaseAuth) { user, provider in
                environment.analyticsService.track(
                    event: AnalyticsEvent(
                        name: "auth_success",
                        parameters: ["provider": provider]
                    )
                )
                Task { await refreshGateState() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .needsConsent(let profile):
            ConsentView(repo: profilesRepository, onCompleted: {
                Task { await refreshGateState() }
            })
            .onAppear {
                appState.currentUser = mapDomainUser(from: profile)
            }
        case .ready(let profile):
            mainTabView
                .onAppear {
                    if appState.currentUser == nil {
                        appState.currentUser = mapDomainUser(from: profile)
                    }
                }
        case .error(let message):
            VStack(spacing: MASpacing.md) {
                MATypography.title("No pudimos cargar tu sesión")
                MATypography.body(message)
                MAButton("Reintentar") {
                    Task { await refreshGateState() }
                }
            }
            .padding()
        }
    }

    private func refreshGateState() async {
        guard appState.hasCompletedOnboarding else {
            gateState = .needsAuth
            appState.currentUser = nil
            return
        }

        guard supabaseAuth.isAuthenticated, let supaUser = supabaseAuth.user else {
            gateState = .needsAuth
            appState.currentUser = nil
            return
        }

        gateState = .loading

        do {
            var profile = try await profilesRepository.getMyProfile()
            if profile == nil {
                let fallbackEmail = supaUser.email ?? ""
                try await profilesRepository.upsertMyProfile(email: fallbackEmail)
                profile = try await profilesRepository.getMyProfile()
            }

            guard let profile else {
                gateState = .error("No pudimos obtener tu perfil.")
                return
            }

            if profile.consent {
                let user = mapDomainUser(from: profile)
                appState.currentUser = user
                gateState = .ready(profile)
            } else {
                gateState = .needsConsent(profile)
                appState.currentUser = nil
            }
        } catch {
            gateState = .error(error.localizedDescription)
        }
    }

    private func mapDomainUser(from profile: UserProfile) -> User {
        User(
            id: profile.user_id.uuidString,
            email: profile.email,
            sport: nil,
            university: profile.university,
            consent: profile.consent,
            createdAt: profile.created_at
        )
    }
}

private struct TestsOverviewStandaloneContainer: View {
    @StateObject private var viewModel: TestsOverviewViewModel

    init(analytics: AnalyticsServiceProtocol) {
        _viewModel = StateObject(wrappedValue: TestsOverviewViewModel(
            databaseService: SupabaseDatabaseService(),
            analytics: analytics
        ))
    }

    var body: some View {
        TestsOverviewView(
            viewModel: viewModel,
            onAssessmentCompleted: {
                Task { await viewModel.refresh() }
            }
        )
    }
}

#Preview {
    RootView(appState: AppState(currentUser: .mock, hasCompletedOnboarding: true), environment: .live())
}

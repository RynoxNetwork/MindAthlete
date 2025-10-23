import Foundation
import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @State private var didAppear = false
    @State private var checkInBounceTrigger = 0
    @State private var showTestsOverview = false
    @State private var testsCtaTrigger = 0

    // MARK: - Brand Colors (local helpers)
    private let brandTurquoise = Color(red: 27/255, green: 166/255, blue: 166/255) // #1BA6A6
    private let brandOrange    = Color(red: 241/255, green: 143/255, blue: 1/255)  // #F18F01
    private let neutral900     = Color(red: 15/255, green: 23/255, blue: 42/255)   // #0F172A
    private let neutral500     = Color(red: 71/255, green: 85/255, blue: 105/255)  // #475569
    private let testsRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var todayString: String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEE, d 'de' MMMM"
        return df.string(from: Date()).capitalized
    }

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            NavigationLink(isActive: $showTestsOverview) {
                TestsOverviewContainer(homeViewModel: viewModel) {
                    Task { await viewModel.load() }
                }
            } label: {
                EmptyView()
            }
            .hidden()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: MASpacing.xl) {
                    if let hero = viewModel.hero {
                        heroHeader(hero)
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(0.00), value: didAppear)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    testsReminderCard

                    checkInCard
                        .cardStyle()
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(0.05), value: didAppear)

                    agendaCard
                        .cardStyle()
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(0.10), value: didAppear)

                    recommendationCard
                        .cardStyle()
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(0.15), value: didAppear)

                    habitsCard
                        .cardStyle()
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9).delay(0.20), value: didAppear)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, MASpacing.lg)
                .padding(.bottom, MASpacing.xl)
            }
            .scrollBounceBehavior(.always)
            .coordinateSpace(name: "homeScroll")
            .background(
                ZStack {
                    Color.maBackground.ignoresSafeArea()
                    LinearGradient(colors: [brandTurquoise.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .center)
                        .ignoresSafeArea()
                }
            )
            .navigationTitle("Hoy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 12) {
                    Label(todayString, systemImage: "calendar")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: { /* quick action: e.g., open weekly summary */ }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Resumen")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule().stroke(brandTurquoise.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ver resumen")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    Divider()
                        .opacity(0.6), alignment: .bottom
                )
                .transition(.opacity)
            }
            .task {
                await viewModel.load()
            }
            .onAppear { didAppear = true }
            .animation(.easeInOut(duration: 0.2), value: viewModel.habitsProgress?.completionPercent ?? 0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        }
    }

    // MARK: - Hero Header
    private func heroHeader(_ hero: HomeViewModel.HeroContent) -> some View {
        GeometryReader { proxy in
            // Compute a subtle parallax based on scroll position
            let minY = proxy.frame(in: .named("homeScroll")).minY
            let parallax = min(max(minY / 100, -0.5), 0.5) // clamp

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brandTurquoise.opacity(0.85), brandOrange.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 2)
                            .blur(radius: 2)
                            .offset(x: 120, y: -40)
                    )
                    .shadow(color: brandTurquoise.opacity(0.25), radius: 16, x: 0, y: 8)

                HStack(alignment: .center, spacing: MASpacing.md) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 54, height: 54)
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        // Concise subtitle above the quote
                        Text(hero.greeting)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))

                        ViewThatFits(in: .vertical) {
                            // Multiline variant
                            Text(hero.quote)
                                .font(.title3.weight(.semibold))
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .minimumScaleFactor(0.9)
                                .foregroundStyle(.white)

                            // Scroll fallback with fade masks
                            ScrollView(.vertical, showsIndicators: false) {
                                Text(hero.quote)
                                    .font(.title3.weight(.semibold))
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)
                                    .minimumScaleFactor(0.9)
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 4)
                            }
                            .mask(
                                LinearGradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black,  location: 0.08),
                                    .init(color: .black,  location: 0.92),
                                    .init(color: .clear, location: 1.0)
                                ], startPoint: .top, endPoint: .bottom)
                            )
                        }

                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 2)
                            .padding(.trailing, MASpacing.xl)
                    }
                    Spacer()
                }
                .padding(MASpacing.lg)
            }
            .scaleEffect(1 + parallax * 0.02)
            .offset(y: parallax * 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("MindAthlete, entrena tu mente y mejora tu rendimiento")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 136) // fixed height within 120–140
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Cards
    private var checkInCard: some View {
        MACard(title: "¿Cómo te sientes?") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce, value: checkInBounceTrigger)
                    MATypography.body("Registra tu mood y energía para entrenar tu autoconocimiento.")
                }
                if viewModel.hasCheckInToday {
                    Label("Registro hecho", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(brandTurquoise)
                }
                MAButton("Registrar check-in") {
                    checkInBounceTrigger += 1
                    // Navigate to diary check-in flow
                }
                .sensoryFeedback(.selection, trigger: checkInBounceTrigger)
                .contentShape(Rectangle())
                .padding(.vertical, 8)
                .accessibilityLabel("Registrar check-in de ánimo")
            }
        }
        .overlayTopAccent(color: brandTurquoise)
    }

    @ViewBuilder
    private var testsReminderCard: some View {
        if viewModel.pendingTests.isEmpty {
            EmptyView()
        } else {
            let statuses = viewModel.testStatuses
            let pending = viewModel.pendingTests
            let actionable = pending.filter { instrument in
                guard let status = statuses[instrument] else { return false }
                return status.isActionable
            }
            let lockedDates = pending.compactMap { instrument -> Date? in
                guard let status = statuses[instrument] else { return nil }
                if case .lockedUntil(let date) = status { return date }
                return nil
            }
            let nextLockedDate = lockedDates.min()
            let isCTAEnabled = !actionable.isEmpty
            MACard {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        Text("Completa tus chequeos mentales")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(neutral900)
                        Text("Ayúdanos a personalizar tus recomendaciones. Realiza los tests POMS, IDEP y Autoestima.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(neutral500)
                    }

                    let pendingList = pending.map { $0.shortTitle }.joined(separator: ", ")
                    if !pendingList.isEmpty {
                        Text("Pendientes: \(pendingList)")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(brandOrange)
                    }

                    if !isCTAEnabled, let lockedDate = nextLockedDate {
                        let relative = testsRelativeFormatter.localizedString(for: lockedDate, relativeTo: Date())
                        Text("Disponible \(relative)")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(neutral500)
                    }

                    MAButton("Realizar tests", style: .outline) {
                        guard isCTAEnabled else { return }
                        testsCtaTrigger += 1
                        viewModel.trackHomeTestsCTA()
                        showTestsOverview = true
                    }
                    .disabled(!isCTAEnabled)
                    .sensoryFeedback(.selection, trigger: testsCtaTrigger)
                }
            }
            .overlayTopAccent(color: brandTurquoise)
            .cardStyle()
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var agendaCard: some View {
        MACard(title: "Hoy en tu agenda") {
            if let agenda = viewModel.agendaPreview {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    if agenda.items.isEmpty {
                        MATypography.body("No tienes eventos hoy. Aprovecha para sumar un micro entrenamiento mental.")
                    } else {
                        HStack(spacing: MASpacing.xs) {
                            ForEach(agenda.items) { item in
                                eventChip(time: item.timeRange, title: item.title, systemImage: item.iconName)
                            }
                        }
                    }

                    Divider().padding(.vertical, MASpacing.sm)

                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        Text("Huecos libres")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(neutral900)
                        if agenda.freeSlots.isEmpty {
                            MATypography.caption("Tu día está completo. Busca 90 segundos entre actividades para un reset rápido.")
                        } else {
                            HStack(spacing: MASpacing.xs) {
                                ForEach(agenda.freeSlots) { slot in
                                    MAChip("\(slot.label)", style: .filled)
                                }
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: MASpacing.sm) {
                    ProgressView()
                    Text("Analizando tu día...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(neutral500)
                }
            }
        }
        .overlayTopAccent(color: brandTurquoise.opacity(0.8))
    }

    private var recommendationCard: some View {
        MACard(title: "Recomendación de hoy") {
            if let recommendation = viewModel.recommendation {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    HStack(spacing: MASpacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(brandOrange)
                        Text("Para hoy a las \(Self.agendaTimeFormatter.string(from: recommendation.scheduledAt))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(neutral500)
                    }

                    Text(recommendation.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(neutral900)
                    MATypography.body(recommendation.body)

                    MAButton(recommendation.actionTitle, style: .secondary) {
                        viewModel.trackRecommendationTap()
                    }
                }
            } else if viewModel.isLoading {
                HStack(spacing: MASpacing.sm) {
                    ProgressView()
                    Text("Cargando recomendaciones...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(neutral500)
                }
            } else {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    MATypography.body("Activa tu coach con IA para recibir recomendaciones personalizadas cada mañana.")
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(brandOrange)
                        Text("Mejora continua, todos los días")
                            .font(.caption)
                            .foregroundStyle(neutral500)
                    }
                }
            }
        }
        .overlayTopAccent(color: brandOrange)
    }

    private var habitsCard: some View {
        MACard(title: "Progreso de hábitos") {
            if let progress = viewModel.habitsProgress {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    HStack(spacing: MASpacing.sm) {
                        Label("Racha: \(progress.streak)d", systemImage: "flame.fill")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(brandOrange)
                        Spacer()
                        Text("\(Int(progress.completionPercent * 100))% del mes")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(neutral500)
                    }
                    ProgressView(value: progress.completionPercent)
                        .progressViewStyle(.linear)
                        .tint(brandTurquoise)
                    MATypography.body(progress.message)
                    MAButton("Ver todos", style: .tertiary) {
                        // navigate to habits
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    MATypography.body("Configura tus hábitos para comenzar a rastrear tu progreso diario.")
                    MAButton("Crear hábito", style: .secondary) {
                        // navigate
                    }
                }
            }
        }
        .overlayTopAccent(color: brandTurquoise)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(brandOrange)
                Image(systemName: "figure.run")
                    .foregroundStyle(brandTurquoise)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Top info bar (under large title)
    private var topInfoBar: some View {
        HStack(spacing: 12) {
            Label(todayString, systemImage: "calendar")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: { /* quick action: e.g., open weekly summary */ }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Resumen")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(.thinMaterial)
                )
                .overlay(
                    Capsule().stroke(brandTurquoise.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ver resumen")
        }
        .padding(.horizontal, MASpacing.lg)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Divider()
                .opacity(0.6), alignment: .bottom
        )
        .transition(.opacity)
    }

    // MARK: - Helpers
    private static let agendaTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func eventChip(time: String, title: String, systemImage: String?) -> some View {
        HStack(spacing: MASpacing.xs) {
            Text(time)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(brandTurquoise))

            HStack(spacing: MASpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(neutral500)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(neutral500)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().stroke(neutral500.opacity(0.2)))
        }
    }

}

private struct TestsOverviewContainer: View {
    @ObservedObject var homeViewModel: HomeViewModel
    let onCompleted: () -> Void
    @StateObject private var testsViewModel: TestsOverviewViewModel

    init(homeViewModel: HomeViewModel, onCompleted: @escaping () -> Void) {
        self.homeViewModel = homeViewModel
        self.onCompleted = onCompleted
        _testsViewModel = StateObject(wrappedValue: homeViewModel.makeTestsOverviewViewModel())
    }

    var body: some View {
        TestsOverviewView(
            viewModel: testsViewModel,
            onAssessmentCompleted: onCompleted
        )
    }
}

// MARK: - Small helpers
private extension View {
    func cardStyle() -> some View {
        self
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
            .transition(.opacity)
    }

    func overlayTopAccent(color: Color) -> some View {
        self
            .overlay(
                Rectangle()
                    .fill(color.opacity(0.35))
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .padding(.horizontal, 20)
                , alignment: .top
            )
    }
}

private func labelWithIcon(text: String, systemImage: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Image(systemName: systemImage)
            .foregroundStyle(.secondary)
        MATypography.body(text)
    }
}

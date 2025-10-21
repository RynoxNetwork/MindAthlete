import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    // MARK: - Brand Colors (local helpers)
    private let brandTurquoise = Color(red: 27/255, green: 166/255, blue: 166/255) // #1BA6A6
    private let brandOrange    = Color(red: 241/255, green: 143/255, blue: 1/255)  // #F18F01
    private let neutral900     = Color(red: 15/255, green: 23/255, blue: 42/255)   // #0F172A
    private let neutral500     = Color(red: 71/255, green: 85/255, blue: 105/255)  // #475569

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
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: MASpacing.lg) {
                    if let hero = viewModel.hero {
                        heroHeader(hero)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    checkInCard
                        .cardStyle()

                    agendaCard
                        .cardStyle()

                    recommendationCard
                        .cardStyle()

                    habitsCard
                        .cardStyle()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, MASpacing.lg)
                .padding(.top, MASpacing.lg)
                .padding(.bottom, MASpacing.xl)
            }
            .scrollBounceBehavior(.always)
            .background(
                ZStack {
                    Color.maBackground.ignoresSafeArea()
                    LinearGradient(colors: [brandTurquoise.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .center)
                        .ignoresSafeArea()
                }
            )
            .navigationTitle("Hoy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .top) {
                topInfoBar
            }
            .task {
                await viewModel.load()
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.habitsProgress?.completionPercent ?? 0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        }
    }

    // MARK: - Hero Header
    private func heroHeader(_ hero: HomeViewModel.HeroContent) -> some View {
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
                    Text(hero.greeting)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(hero.quote)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 2)
                        .padding(.trailing, MASpacing.xl)
                }
                Spacer()
            }
            .padding(MASpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MindAthlete, entrena tu mente y mejora tu rendimiento")
    }

    // MARK: - Cards
    private var checkInCard: some View {
        MACard(title: "¿Cómo te sientes?") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                labelWithIcon(text: "Registra tu mood y energía para entrenar tu autoconocimiento.", systemImage: "face.smiling")
                if viewModel.hasCheckInToday {
                    Label("Registro hecho", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(brandTurquoise)
                }
                MAButton("Registrar check-in") {
                    // Navigate to diary check-in flow
                }
                .accessibilityLabel("Registrar check-in de ánimo")
            }
        }
        .overlayTopAccent(color: brandTurquoise)
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
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
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

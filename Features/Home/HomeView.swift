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
                    heroHeader
                        .transition(.move(edge: .top).combined(with: .opacity))

                    checkInCard
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
            .animation(.easeInOut(duration: 0.2), value: viewModel.habits)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
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
                    Text("Bienvenido de vuelta")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Entrena tu mente. Mejora tu rendimiento.")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
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
                MAButton("Registrar check-in") {
                    // Navigate to diary check-in flow
                }
                .accessibilityLabel("Registrar check-in de ánimo")
            }
        }
        .overlayTopAccent(color: brandTurquoise)
    }

    private var recommendationCard: some View {
        MACard(title: "Recomendación de hoy") {
            if let recommendation = viewModel.todaysRecommendation {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    HStack(spacing: MASpacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(brandOrange)
                        Text("Sugerencias para ti")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(neutral500)
                    }

                    ForEach(recommendation.recommendations, id: \.self) { tip in
                        MATypography.body("• \(tip)")
                            .transition(.opacity)
                    }

                    if let preCompetition = recommendation.preCompetition {
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text("Pre-competencia")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(brandTurquoise)
                            MATypography.body(preCompetition)
                        }
                        .transition(.opacity)
                    }

                    HStack(spacing: MASpacing.sm) {
                        MAButton("Me ayudó", style: .secondary) {
                            // feedback positive
                        }
                        MAButton("No hoy", style: .tertiary) {
                            // feedback negative
                        }
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
            if viewModel.habits.isEmpty {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    MATypography.body("Aún no tienes hábitos activos. Crea uno para consolidar tu rutina.")
                    MAButton("Crear hábito", style: .secondary) {
                        // navigate to habits setup
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    ForEach(viewModel.habits) { habit in
                        HStack(spacing: MASpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(brandTurquoise.opacity(habit.active ? 0.15 : 0.07))
                                    .frame(width: 36, height: 36)
                                Image(systemName: habit.active ? "checkmark.circle.fill" : "pause.circle")
                                    .foregroundStyle(habit.active ? brandTurquoise : neutral500)
                            }

                            VStack(alignment: .leading, spacing: MASpacing.xs) {
                                Text(habit.name)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(MAColorPalette.textPrimary)
                                MATypography.caption("Meta semanal: \(habit.targetPerWeek)x")
                            }
                            Spacer()
                            MAChip(habit.active ? "Act." : "Pausado", style: habit.active ? .filled : .outlined)
                                .accessibilityLabel(habit.active ? "Hábito activo" : "Hábito pausado")
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        Divider()
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

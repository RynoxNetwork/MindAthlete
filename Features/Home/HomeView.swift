
import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MASpacing.lg) {
                    checkInCard
                    recommendationCard
                    habitsCard
                }
                .padding(.horizontal, MASpacing.lg)
                .padding(.vertical, MASpacing.lg)
            }
            .background(Color.maBackground.ignoresSafeArea())
            .navigationTitle("Hoy")
            .task {
                await viewModel.load()
            }
        }
    }

    private var checkInCard: some View {
        MACard(title: "¿Cómo te sientes?") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                MATypography.body("Registra tu mood y energía para entrenar tu autoconocimiento.")
                MAButton("Registrar check-in") {
                    // Navigate to diary check-in flow
                }
                .accessibilityLabel("Registrar check-in de ánimo")
            }
        }
    }

    private var recommendationCard: some View {
        MACard(title: "Recomendación de hoy") {
            if let recommendation = viewModel.todaysRecommendation {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    ForEach(recommendation.recommendations, id: \.self) { tip in
                        MATypography.body("• \(tip)")
                    }

                    if let preCompetition = recommendation.preCompetition {
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text("Pre-competencia")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(MAColorPalette.accent)
                            MATypography.body(preCompetition)
                        }
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
                ProgressView()
            } else {
                MATypography.body("Activa tu coach con IA para recibir recomendaciones personalizadas cada mañana.")
            }
        }
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
                        HStack {
                            VStack(alignment: .leading, spacing: MASpacing.xs) {
                                Text(habit.name)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(MAColorPalette.textPrimary)
                                MATypography.caption("Meta semanal: \(habit.targetPerWeek)x")
                            }
                            Spacer()
                            MAChip("Act.", style: habit.active ? .filled : .outlined)
                                .accessibilityLabel(habit.active ? "Hábito activo" : "Hábito pausado")
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

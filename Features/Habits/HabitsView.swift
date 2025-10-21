import SwiftUI

private extension Double {
    var clamped01: Double { max(0, min(self, 1)) }
}

struct HabitsView: View {
    @StateObject private var viewModel: HabitsViewModel
    @State private var showingNewHabitSheet = false
    @State private var noteTarget: HabitsViewModel.Habit?
    @State private var noteText: String = ""

    init(viewModel: HabitsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MASpacing.lg) {
                    header

                    if viewModel.isLoading {
                        HabitsSkeletonView()
                    } else if viewModel.activeHabits.isEmpty {
                        EmptyHabitsState {
                            showingNewHabitSheet = true
                        }
                    } else {
                        DashboardHeader(
                            streak: viewModel.bestCurrentStreak,
                            weekProgress: viewModel.combinedWeekProgress,
                            monthlyAdherence: viewModel.averageMonthlyAdherence
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeOut(duration: 0.18), value: viewModel.bestCurrentStreak)

                        if viewModel.shouldShowFreeTierBanner {
                            FreeTierBanner()
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        VStack(spacing: MASpacing.md) {
                            ForEach(viewModel.activeHabits) { habit in
                                NavigationLink {
                                    HabitDetailView(viewModel: viewModel, habit: habit)
                                } label: {
                                    HabitCard(
                                        habit: habit,
                                        streak: viewModel.currentStreak(for: habit, logs: viewModel.logs),
                                        monthlyAdherence: viewModel
                                            .monthlyAdherence(viewModel.logs, for: habit)
                                            .last ?? 0,
                                        weekProgress: viewModel.weekProgress(for: habit, logs: viewModel.logs, in: viewModel.currentWeekInterval()),
                                        onCheckToday: { partial in viewModel.toggleToday(for: habit, partial: partial) },
                                        onAddNote: {
                                            noteTarget = habit
                                            noteText = ""
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                }
                .padding(.horizontal, MASpacing.lg)
                .padding(.vertical, MASpacing.lg)
            }
            .background(Color.maBackground.ignoresSafeArea())
            .navigationTitle("Hábitos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuevo hábito") {
                        showingNewHabitSheet = true
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(isPresented: $showingNewHabitSheet) {
                NewHabitSheet(viewModel: viewModel)
            }
            .sheet(item: $noteTarget) { habit in
                NavigationStack {
                    Form {
                        Section("Nota de hoy") {
                            TextField("Escribe una nota breve", text: $noteText, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    .navigationTitle(habit.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { noteTarget = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Guardar") {
                                viewModel.addNote(noteText, to: habit)
                                noteTarget = nil
                            }
                            .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .padding(.top, 12)
                        .padding(.horizontal, MASpacing.lg)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Hábitos activos")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Nuevo hábito") {
                showingNewHabitSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(MAColorPalette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

// MARK: - Skeleton
private struct HabitsSkeletonView: View {
    var body: some View {
        VStack(spacing: MASpacing.md) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.maSurface.opacity(0.5))
                .frame(height: 140)
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.maSurface.opacity(0.6))
                    .frame(height: 120)
            }
        }
        .shimmer()
    }
}

// MARK: - Empty State
private struct EmptyHabitsState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: MASpacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(MAColorPalette.primary.opacity(0.8))
            Text("Aún no tienes hábitos activos")
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Crea tu primer hábito para empezar a registrar tus rutinas diarias.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Crear hábito") { onCreate() }
                .buttonStyle(.borderedProminent)
                .tint(MAColorPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MASpacing.lg)
        .padding(.horizontal, MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Banners
private struct FreeTierBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: MASpacing.md) {
            Image(systemName: "crown.fill")
                .foregroundStyle(MAColorPalette.accent)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(MAColorPalette.accent.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text("Límite de 3 hábitos activos (Free)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Actualiza tu plan para desbloquear hábitos ilimitados.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(MAColorPalette.textSecondary)
            }
            Spacer()
            Button("Mejorar") {}
                .buttonStyle(.borderedProminent)
                .tint(MAColorPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MAColorPalette.primary.opacity(0.1))
        )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: MASpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.white)
            Text(message)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MAColorPalette.accent700.opacity(0.9))
        )
        .foregroundStyle(Color.white)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Shimmer
private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.45),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 1.6)
                    .offset(x: phase * width * 1.6)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#if DEBUG
#Preview("Hábitos – lista completa") {
    HabitsView(viewModel: HabitsViewModel.preview())
        .preferredColorScheme(.light)
}

#Preview("Hábitos – vacío Dark") {
    HabitsView(viewModel: HabitsViewModel(
        userId: "preview",
        database: DatabaseService(),
        analytics: AnalyticsService(),
        habits: [],
        logs: []
    ))
    .preferredColorScheme(.dark)
}
#endif

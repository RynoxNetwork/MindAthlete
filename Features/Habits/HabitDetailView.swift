import SwiftUI

struct HabitDetailView: View {
    @ObservedObject private var viewModel: HabitsViewModel
    private let habitId: UUID
    private let initialHabit: HabitsViewModel.Habit

    @Environment(\.dismiss) private var dismiss
    @State private var localGoal: Int
    @State private var localIsActive: Bool

    init(viewModel: HabitsViewModel, habit: HabitsViewModel.Habit) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.habitId = habit.id
        self.initialHabit = habit
        _localGoal = State(initialValue: habit.goalPerWeek)
        _localIsActive = State(initialValue: habit.isActive)
    }

    private var habit: HabitsViewModel.Habit {
        viewModel.habits.first(where: { $0.id == habitId }) ?? initialHabit
    }

    private var logs: [HabitsViewModel.HabitLog] {
        viewModel.logs(for: habit)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MASpacing.lg) {
                header
                weekGrid
                recentLogs
                actionsSection
            }
            .padding(MASpacing.lg)
        }
        .background(Color.maBackground.ignoresSafeArea())
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cerrar") { dismiss() }
            }
        }
        .onReceive(viewModel.$habits) { _ in
            localGoal = habit.goalPerWeek
            localIsActive = habit.isActive
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            Text(habit.name)
                .font(.system(.title2, design: .rounded).weight(.semibold))
            Text(habit.description)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)

            MAChip(
                localIsActive ? "Activo" : "Pausado",
                style: localIsActive ? .filled : .outlined
            )

            let weekProgress = viewModel.weekProgress(for: habit, logs: logs, in: viewModel.currentWeekInterval())
            Text("Meta semanal: \(formatted(weekProgress.done)) / \(weekProgress.goal)")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekGrid: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            Text("Esta semana")
                .font(.system(.headline, design: .rounded))
            WeekGridView(
                logs: logs,
                currentWeek: viewModel.currentWeekInterval(),
                habitId: habit.id
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var recentLogs: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            Text("Registros recientes")
                .font(.system(.headline, design: .rounded))

            if logs.isEmpty {
                Text("Todavía no hay registros para este hábito.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(MAColorPalette.textSecondary)
            } else {
                ForEach(logs.prefix(7)) { log in
                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        HStack {
                            Text(log.performedAt, style: .date)
                                .font(.system(.subheadline, design: .rounded))
                            Spacer()
                            Text("\(Int(log.adherence * 100))%")
                                .font(.system(.subheadline, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(MAColorPalette.primary)
                        }
                        if let note = log.notes, !note.isEmpty {
                            Text(note)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(MAColorPalette.textSecondary)
                        }
                    }
                    .padding(.vertical, MASpacing.xs)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            Text("Acciones")
                .font(.system(.headline, design: .rounded))

            VStack(spacing: MASpacing.sm) {
                Stepper(value: $localGoal, in: 0...7, step: 1) {
                    Text("Meta semanal: \(localGoal)")
                        .font(.system(.body, design: .rounded))
                }
                .onChange(of: localGoal) { newValue in
                    viewModel.updateGoal(for: habit, goal: newValue)
                }

                Toggle("Activo", isOn: Binding(
                    get: { localIsActive },
                    set: {
                        localIsActive = $0
                        viewModel.setActive($0, for: habit)
                    }
                ))
                .font(.system(.body, design: .rounded))

                Button {
                    viewModel.toggleToday(for: habit, partial: false)
                } label: {
                    Label("Registrar hoy", systemImage: "checkmark.circle")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MAColorPalette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(MASpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MAColorPalette.primary.opacity(0.08))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private struct WeekGridView: View {
    let logs: [HabitsViewModel.HabitLog]
    let currentWeek: DateInterval
    let habitId: UUID

    private var days: [Date] {
        let calendar = Calendar.current
        return stride(from: 0, to: 7, by: 1).compactMap {
            calendar.date(byAdding: .day, value: $0, to: currentWeek.start)
        }
    }

    var body: some View {
        let calendar = Calendar.current
        return HStack(spacing: MASpacing.sm) {
            ForEach(days, id: \.self) { day in
                let hasLog = logs.contains {
                    $0.habitId == habitId && calendar.isDate($0.performedAt, inSameDayAs: day)
                }
                VStack(spacing: MASpacing.xs) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)
                    Image(systemName: hasLog ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(hasLog ? MAColorPalette.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MASpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hasLog ? MAColorPalette.primary.opacity(0.12) : Color.clear)
                )
            }
        }
    }
}

#if DEBUG
#Preview("Habit detail") {
    let vm = HabitsViewModel.preview()
    if let habit = vm.activeHabits.first {
        NavigationStack {
            HabitDetailView(viewModel: vm, habit: habit)
        }
    }
}
#endif

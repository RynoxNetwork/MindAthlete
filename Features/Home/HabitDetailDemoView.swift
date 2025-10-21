#if DEMO_UI
import SwiftUI

struct HabitDetailDemoView: View {
    let habit: Habit
    @ObservedObject var vm: HabitsDemoViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader("Esta semana")
                weekGrid

                SectionHeader("Registros recientes")
                recentLogs

                SectionHeader("Acciones")
                actions
            }
            .padding(16)
        }
        .navigationTitle(habit.name)
    }

    private var weekGrid: some View {
        let week = vm.currentWeekInterval()
        let cal = Calendar.current
        let days = stride(from: 0, to: 7, by: 1).compactMap { cal.date(byAdding: .day, value: $0, to: week.start) }
        return HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let hasLog = vm.logs.contains { $0.habitId == habit.id && cal.isDate($0.performedAt, inSameDayAs: day) }
                VStack {
                    Text(day, format: Date.FormatStyle().day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: hasLog ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(hasLog ? BrandPalette.turquoise : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var recentLogs: some View {
        let cal = Calendar.current
        let recent = vm.logs
            .filter { $0.habitId == habit.id }
            .sorted { $0.performedAt > $1.performedAt }
            .prefix(10)
        return VStack(spacing: 8) {
            ForEach(recent) { log in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: log.adherence >= 1 ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                        .foregroundStyle(log.adherence >= 1 ? BrandPalette.turquoise : BrandPalette.orange)
                    VStack(alignment: .leading) {
                        Text(cal.isDateInToday(log.performedAt) ? "Hoy" : log.performedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        if let n = log.notes, !n.isEmpty {
                            Text(n).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(Int(log.adherence * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                // UI-only
            } label: { Label("Editar meta semanal", systemImage: "pencil") }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                // UI-only deactivate
                // Toggling would require binding; kept simple for mock
            } label: { Label("Desactivar hábito", systemImage: "xmark.circle") }
            .buttonStyle(.bordered)
        }
    }
}

#Preview("Detalle hábito") {
    let vm = HabitsDemoViewModel()
    return NavigationStack {
        HabitDetailDemoView(habit: vm.activeHabits.first ?? vm.habits.first!, vm: vm)
    }
}
#endif

#if DEMO_UI
import SwiftUI

struct DashboardHeaderDemo: View {
    @ObservedObject var vm: HabitsDemoViewModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StreakCard(streak: vm.bestCurrentStreak)
                WeeklyGoalCard(done: vm.combinedWeekProgress.done, goal: vm.combinedWeekProgress.goal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MonthlyAdherenceSparkline(values: vm.averageMonthlyAdherence)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Resumen de hábitos")
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct StreakCard: View {
    let streak: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(BrandPalette.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Racha")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(streak)d")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
        )
    }
}

private struct WeeklyGoalCard: View {
    let done: Double
    let goal: Int
    var progress: Double { goal == 0 ? 0 : min(done / Double(goal), 1).clamped01 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Esta semana")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("\(Int(done)) / \(goal)")
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
            }
            ProgressView(value: progress)
                .tint(BrandPalette.turquoise)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
        )
    }
}

struct MonthlyAdherenceSparkline: View {
    let values: [Double] // last 30 days 0..1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Últimos 30 días")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let step = values.isEmpty ? 0 : w / CGFloat(values.count - 1)
                Path { path in
                    for (idx, v) in values.enumerated() {
                        let x = CGFloat(idx) * step
                        let y = h - CGFloat(v) * h
                        if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(BrandPalette.turquoise, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                .animation(.easeInOut(duration: 0.2), value: values)
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BrandPalette.turquoise.opacity(0.08))
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
        )
    }
}

#Preview("Dashboard Header – Light") {
    let vm = HabitsDemoViewModel()
    DashboardHeaderDemo(vm: vm)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Dashboard Header – Dark") {
    let vm = HabitsDemoViewModel()
    DashboardHeaderDemo(vm: vm)
        .padding()
        .preferredColorScheme(.dark)
}

#endif

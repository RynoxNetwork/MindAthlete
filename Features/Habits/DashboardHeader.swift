import SwiftUI

private extension Double {
    var clamped01: Double { max(0, min(self, 1)) }
}

struct DashboardHeader: View {
    let streak: Int
    let weekProgress: (done: Double, goal: Int)
    let monthlyAdherence: [Double]

    var body: some View {
        VStack(spacing: MASpacing.lg) {
            HStack(spacing: MASpacing.md) {
                StreakCard(streak: streak)
                WeeklyGoalCard(done: weekProgress.done, goal: weekProgress.goal)
            }

            MonthlyAdherenceSparkline(values: monthlyAdherence)
        }
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Resumen de hábitos")
    }
}

private struct StreakCard: View {
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            Label("Racha", systemImage: "flame.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(MAColorPalette.accent)
            Text("\(streak)d")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text("Días consecutivos completando tus hábitos.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
        }
        .padding(MASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MAColorPalette.primary.opacity(0.1))
        )
    }
}

private struct WeeklyGoalCard: View {
    let done: Double
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(done / Double(goal), 1).clamped01
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    private var formattedDone: String {
        if done.rounded(.towardZero) == done {
            return String(Int(done))
        }
        return String(format: "%.1f", done)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            Text("Esta semana")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: MASpacing.xs) {
                Text(formattedDone)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("/ \(goal)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(MAColorPalette.primary)
                .accessibilityLabel("Progreso semanal")
                .accessibilityValue("\(percentage) por ciento completado")
            Text("Meta alcanzada al \(percentage)%")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
        }
        .padding(MASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MAColorPalette.primary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct MonthlyAdherenceSparkline: View {
    let values: [Double]

    private var percentage: Int {
        Int((values.last ?? 0).clamped01 * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            HStack {
                Text("Adherencia 30 días")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Text("\(percentage)%")
                    .font(.system(.subheadline, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MAColorPalette.textSecondary)
            }

            GeometryReader { proxy in
                let size = proxy.size
                let data = values.isEmpty ? [Double](repeating: 0, count: 30) : values
                let stepX = size.width / CGFloat(max(data.count - 1, 1))

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: size.height))
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = (1 - value.clamped01) * size.height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: size.width, y: size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                MAColorPalette.primary.opacity(0.35),
                                MAColorPalette.primary.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        guard let first = data.first else { return }
                        path.move(to: CGPoint(x: 0, y: (1 - first.clamped01) * size.height))
                        for (index, value) in data.enumerated().dropFirst() {
                            let x = CGFloat(index) * stepX
                            let y = (1 - value.clamped01) * size.height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(MAColorPalette.primary, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MAColorPalette.primary.opacity(0.05))
            )
        }
    }
}

#if DEBUG
#Preview("Dashboard header") {
    DashboardHeader(
        streak: 12,
        weekProgress: (done: 3.5, goal: 5),
        monthlyAdherence: stride(from: 0, to: 1.0, by: 0.03).map { sin($0 * .pi).magnitude }
    )
    .padding()
    .preferredColorScheme(.light)
}
#endif

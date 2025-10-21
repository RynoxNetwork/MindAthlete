import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private extension Double {
    var clamped01: Double { max(0, min(self, 1)) }
}

struct HabitCard: View {
    let habit: HabitsViewModel.Habit
    let streak: Int
    let monthlyAdherence: Double
    let weekProgress: (done: Double, goal: Int)

    var onCheckToday: (_ partial: Bool) -> Void
    var onAddNote: () -> Void

    @State private var animateTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: MASpacing.xs) {
                    Text(habit.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(MAColorPalette.textPrimary)
                        .lineLimit(2)
                    Text(habit.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
                todayChip
            }

            VStack(alignment: .leading, spacing: MASpacing.sm) {
                HStack(spacing: MASpacing.sm) {
                    Label("\(streak)d", systemImage: "flame.fill")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(MAColorPalette.accent)
                        .labelStyle(.titleAndIcon)
                        .monospacedDigit()
                    Capsule()
                        .fill(MAColorPalette.accent.opacity(0.2))
                        .frame(width: 1, height: 20)
                    Text("Racha actual")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)
                }

                ProgressView(value: monthlyAdherence.clamped01)
                    .tint(MAColorPalette.primary)
                    .accessibilityLabel("Adherencia mensual")
                    .accessibilityValue("\(Int(monthlyAdherence.clamped01 * 100)) por ciento")

                HStack {
                    Text("Adherencia mensual \(Int(monthlyAdherence.clamped01 * 100))%")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)
                    Spacer()
                    Text("Esta semana: \(formattedDone)/\(weekProgress.goal)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)
                }
            }
        }
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.maSurface)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
        .scaleEffect(animateTap ? 0.98 : 1)
        .animation(.easeOut(duration: 0.18), value: animateTap)
        .contextMenu {
            Button {
                triggerHaptic()
                onCheckToday(true)
            } label: {
                Label("Marcar parcial (0.5)", systemImage: "half.circle")
            }

            Button {
                onAddNote()
            } label: {
                Label("Añadir nota", systemImage: "square.and.pencil")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var formattedDone: String {
        if weekProgress.done.rounded(.towardZero) == weekProgress.done {
            return String(Int(weekProgress.done))
        }
        return String(format: "%.1f", weekProgress.done)
    }

    private var todayChip: some View {
        Button {
            animateTap = true
            triggerHaptic()
            onCheckToday(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateTap = false
            }
        } label: {
            Label("Hoy", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, MASpacing.sm)
                .padding(.vertical, MASpacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .tint(MAColorPalette.primary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .symbolEffect(.bounce)
        .minimumScaleFactor(0.9)
        .accessibilityLabel("Registrar hoy \(habit.name)")
        .frame(minWidth: 44, minHeight: 44)
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

#if DEBUG
#Preview("Habit Card") {
    let habit = HabitsViewModel.preview().activeHabits.first!
    HabitCard(
        habit: habit,
        streak: 7,
        monthlyAdherence: 0.8,
        weekProgress: (done: 3.5, goal: 5),
        onCheckToday: { _ in },
        onAddNote: {}
    )
    .padding()
    .preferredColorScheme(.light)
}
#endif

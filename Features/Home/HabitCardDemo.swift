import SwiftUI

private extension Double {
    var clamped01: Double { max(0, min(self, 1)) }
}

struct HabitCardDemo: View {
    let habit: Habit
    let streak: Int
    let monthlyAdherence: Double // 0..1 for this habit
    let weekProgress: (done: Double, goal: Int)

    var onCheckToday: (_ partial: Bool) -> Void
    var onAddNote: () -> Void

    @State private var animateTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .lineLimit(2)
                    #if DEMO_UI
                    Text(habit.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    #else
                    Text("Objetivo semanal: \(habit.targetPerWeek)x")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    #endif
                }
                Spacer()
                todayChip
            }

            HStack(spacing: 12) {
                Label("\(streak)d", systemImage: "flame.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.orange)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: monthlyAdherence.clamped01, total: 1)
                        .tint(BrandPalette.turquoise)
                    Text("Adherencia mensual \(Int(monthlyAdherence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
        )
        .scaleEffect(animateTap ? 0.98 : 1)
        .animation(.easeOut(duration: 0.18), value: animateTap)
        .contextMenu {
            Button {
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
        .accessibilityElement(children: .combine)
    }

    private var todayChip: some View {
        Button {
            animateTap = true
            onCheckToday(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { animateTap = false }
        } label: {
            Label("Hoy", systemImage: "checkmark.circle")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(BrandPalette.turquoise)
        .symbolEffect(.bounce)
        .accessibilityLabel("Marcar hoy para \(habit.name)")
        .accessibilityHint("Registra el hábito de hoy")
        .frame(minWidth: 44, minHeight: 44)
    }
}

#Preview("Habit Card – largo") {
#if DEMO_UI
HabitCardDemo(
    habit: Habit(name: "Sesión de movilidad y estiramientos después del entrenamiento", description: "10-15 minutos de movilidad para cadera y hombros.", goalPerWeek: 4, isActive: true),
    streak: 12,
    monthlyAdherence: 0.76,
    weekProgress: (3, 4),
    onCheckToday: { _ in },
    onAddNote: {}
)
.padding()
#else
HabitCardDemo(
    habit: Habit(id: "demo", userId: "user_demo", name: "Sesión de movilidad y estiramientos", targetPerWeek: 4, active: true),
    streak: 12,
    monthlyAdherence: 0.76,
    weekProgress: (3, 4),
    onCheckToday: { _ in },
    onAddNote: {}
)
.padding()
#endif
}


import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            MATypography.title(habit.name)
            MATypography.body("Meta semanal: \(habit.targetPerWeek) veces")
            MAChip(habit.active ? "Activo" : "Pausado", style: habit.active ? .filled : .outlined)
        }
        .padding()
        .navigationTitle("Detalle hábito")
    }
}

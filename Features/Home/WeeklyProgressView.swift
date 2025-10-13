
import SwiftUI

struct WeeklyProgressView: View {
    let habits: [Habit]

    var body: some View {
        MACard(title: "Progreso semanal") {
            if habits.isEmpty {
                MATypography.body("Define tus hábitos para visualizar tu progreso.")
            } else {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    ForEach(habits) { habit in
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text(habit.name)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(MAColorPalette.textPrimary)
                            MATypography.caption("Meta semanal: \(habit.targetPerWeek)x")
                        }
                        Divider()
                    }
                }
            }
        }
    }
}


import SwiftUI

struct HabitProgressView: View {
    let habit: Habit
    let logs: [HabitLog]

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            MATypography.body("Cumplidos esta semana: \(logs.filter { $0.value }.count) / \(habit.targetPerWeek)")
            ProgressView(value: progress)
                .tint(MAColorPalette.primary)
        }
    }

    private var progress: Double {
        guard habit.targetPerWeek > 0 else { return 0 }
        return Double(logs.filter { $0.value }.count) / Double(habit.targetPerWeek)
    }
}

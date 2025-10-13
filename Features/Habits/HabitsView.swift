
import SwiftUI

struct HabitsView: View {
    @StateObject var viewModel: HabitsViewModel

    init(viewModel: HabitsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: MASectionHeader(title: "Hábitos activos", actionTitle: "Nuevo hábito", action: {})) {
                if viewModel.habits.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.habits) { habit in
                        HStack {
                            VStack(alignment: .leading, spacing: MASpacing.xs) {
                                Text(habit.name)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(MAColorPalette.textPrimary)
                                MATypography.caption("Meta: \(habit.targetPerWeek)x/semana")
                            }
                            Spacer()
                            Toggle("", isOn: .constant(habit.active))
                                .labelsHidden()
                        }
                        .padding(.vertical, MASpacing.sm)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hábitos")
        .task {
            await viewModel.load()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            MATypography.body("Define hábitos saludables para reforzar tu bienestar deportivo.")
            MAButton("Crear hábito", style: .primary) {}
        }
        .padding(.vertical, MASpacing.lg)
    }
}

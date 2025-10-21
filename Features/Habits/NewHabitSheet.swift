import SwiftUI

struct NewHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: HabitsViewModel

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var goalPerWeek: Int = 3
    @State private var isActive: Bool = true

    init(viewModel: HabitsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Nombre", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .font(.system(.body, design: .rounded))

                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(.body, design: .rounded))
                }

                Section("Meta semanal") {
                    Stepper(value: $goalPerWeek, in: 0...7) {
                        Text("\(goalPerWeek) veces por semana")
                            .font(.system(.body, design: .rounded))
                    }
                }

                Section("Estado") {
                    Toggle("Activo", isOn: $isActive)
                        .font(.system(.body, design: .rounded))
                }
            }
            .navigationTitle("Nuevo hábito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear hábito") {
                        viewModel.createHabit(
                            name: name,
                            description: description,
                            goalPerWeek: goalPerWeek,
                            isActive: isActive
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MAColorPalette.primary)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
#Preview("New habit sheet") {
    NewHabitSheet(viewModel: HabitsViewModel.preview())
}
#endif

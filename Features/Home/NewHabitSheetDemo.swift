#if DEMO_UI
import SwiftUI

struct NewHabitSheetDemo: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: HabitsDemoViewModel

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var goalPerWeek: Int = 3
    @State private var isActive: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Nombre", text: $name)
                    TextField("Descripción", text: $description)
                    Stepper(value: $goalPerWeek, in: 0...7) {
                        HStack {
                            Text("Meta semanal")
                            Spacer()
                            Text("\(goalPerWeek)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Activo", isOn: $isActive)
                }
            }
            .navigationTitle("Nuevo hábito")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear hábito") {
                        vm.createHabit(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                       description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                       goalPerWeek: goalPerWeek,
                                       isActive: isActive)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandPalette.turquoise)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview("Nuevo hábito") {
    NewHabitSheetDemo(vm: HabitsDemoViewModel())
}
#endif

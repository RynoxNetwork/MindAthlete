
import SwiftUI

struct HabitCreationView: View {
    @State private var name: String = ""
    @State private var target: Int = 5

    var onSave: (Habit) -> Void

    var body: some View {
        Form {
            Section(header: Text("Nombre")) {
                TextField("Hábitos", text: $name)
            }
            Section(header: Text("Meta semanal")) {
                Stepper(value: $target, in: 1...14) {
                    Text("\(target) veces")
                }
            }
            Section {
                MAButton("Guardar", style: .primary) {
                    let habit = Habit(id: UUID().uuidString, userId: "", name: name, targetPerWeek: target, active: true)
                    onSave(habit)
                }
            }
        }
        .navigationTitle("Nuevo hábito")
    }
}


import SwiftUI

struct EventCreationView: View {
    @State private var name: String = ""
    @State private var date: Date = .now
    @State private var importance: Int = 3

    var onSave: (Event) -> Void

    var body: some View {
        Form {
            Section(header: Text("Evento")) {
                TextField("Competencia", text: $name)
                DatePicker("Fecha", selection: $date)
                Stepper(value: $importance, in: 1...5) {
                    Text("Importancia: \(importance)")
                }
            }
            Section {
                MAButton("Guardar", style: .primary) {
                    let event = Event(id: UUID().uuidString, userId: "", type: name, date: date, importance: importance)
                    onSave(event)
                }
            }
        }
        .navigationTitle("Nuevo evento")
    }
}

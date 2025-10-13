
import SwiftUI

struct MoodEntryView: View {
    @Binding var moodScore: Double
    @Binding var energyScore: Double
    @Binding var notes: String

    var body: some View {
        Form {
            Section(header: Text("Ánimo")) {
                Slider(value: $moodScore, in: 1...10, step: 1) {
                    Text("Ánimo")
                }
                Text("\(Int(moodScore))/10")
            }

            Section(header: Text("Energía")) {
                Slider(value: $energyScore, in: 1...10, step: 1) {
                    Text("Energía")
                }
                Text("\(Int(energyScore))/10")
            }

            Section(header: Text("Notas")) {
                TextEditor(text: $notes)
                    .frame(height: 120)
            }
        }
        .navigationTitle("Nuevo registro")
    }
}


import SwiftUI

struct NotificationSettingsView: View {
    @Binding var checkInReminder: Bool
    @Binding var competitionReminder: Bool
    
    var body: some View {
        Form {
            Toggle("Recordatorio de check-in", isOn: $checkInReminder)
            Toggle("Recordatorio pre-competencia", isOn: $competitionReminder)
        }
        .navigationTitle("Notificaciones")
    }
}

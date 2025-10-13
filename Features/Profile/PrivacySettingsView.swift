
import SwiftUI

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section(header: Text("Datos")) {
                Button("Descargar datos") {}
                Button("Eliminar cuenta", role: .destructive) {}
            }
        }
        .navigationTitle("Privacidad")
    }
}

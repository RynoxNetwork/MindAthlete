import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    init(viewModel: ProfileViewModel, onSignOut: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSignOut = onSignOut
    }

    var body: some View {
        Form {
            Section(header: Text("Cuenta")) {
                VStack(alignment: .leading, spacing: MASpacing.xs) {
                    Text(viewModel.user.email)
                        .font(.system(.body, design: .rounded))
                    if let sport = viewModel.user.sport {
                        MATypography.caption("Deporte: \(sport)")
                    }
                    if let university = viewModel.user.university {
                        MATypography.caption("Universidad: \(university)")
                    }
                }
            }

            Section(header: Text("Privacidad")) {
                Button("Descargar mis datos") {}
                Button("Eliminar cuenta", role: .destructive) {}
            }

            Section(header: Text("Notificaciones")) {
                Toggle("Recordatorio check-in", isOn: .constant(true))
                Toggle("Recordatorio pre-competencia", isOn: .constant(true))
            }

            Section(header: Text("Accesibilidad")) {
                NavigationLink("Colores de agenda") {
                    AgendaColorSettingsView(store: AgendaColorStore())
                }
            }

            Section(header: Text("Suscripción")) {
                Button("Ver planes (RevenueCat)") {}
            }

            Section {
                Button("Cerrar sesión") {
                    Task {
                        await viewModel.signOut()
                        onSignOut()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Perfil")
    }
}


import SwiftUI

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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

            Section(header: Text("Suscripción")) {
                Button("Ver planes (RevenueCat)") {}
            }

            Section {
                Button("Cerrar sesión") {
                    Task { await viewModel.signOut() }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Perfil")
    }
}

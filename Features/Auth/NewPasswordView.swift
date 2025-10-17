import SwiftUI

struct NewPasswordView: View {
    @ObservedObject var auth: SupabaseAuthService
    var onClose: () -> Void
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nueva contraseña")) {
                    SecureField("Contraseña", text: $newPassword)
                    SecureField("Confirmar contraseña", text: $confirmPassword)
                }

                Section {
                    Button {
                        Task { await updatePassword() }
                    } label: {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Actualizar contraseña")
                        }
                    }
                    .disabled(isProcessing)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else if let infoMessage {
                        Text(infoMessage).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Definir contraseña")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }

    private func updatePassword() async {
        guard !isProcessing else { return }
        guard newPassword == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            infoMessage = nil
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "Usa al menos 8 caracteres."
            infoMessage = nil
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await auth.updatePassword(to: newPassword)
            errorMessage = nil
            infoMessage = "Contraseña actualizada. Usa tu nueva contraseña para iniciar sesión."
        } catch {
            infoMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}

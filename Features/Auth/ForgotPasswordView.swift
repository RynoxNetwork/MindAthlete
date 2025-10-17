import SwiftUI

struct ForgotPasswordView: View {
    @ObservedObject var auth: SupabaseAuthService
    var onClose: () -> Void
    @State private var email: String = ""
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var redirectScheme: URL = URL(string: "mindathlete://password-reset")!

    var body: some View {
        NavigationView {
            Form {
                Section(footer: footerMessage) {
                    TextField("Correo electrónico", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    Button {
                        Task { await sendReset() }
                    } label: {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Enviar enlace de restablecimiento")
                        }
                    }
                    .disabled(isProcessing || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Recuperar contraseña")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }

    @ViewBuilder
    private var footerMessage: some View {
        if let infoMessage {
            Text(infoMessage)
                .foregroundColor(.secondary)
        }
        if let errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
        }
    }

    private func sendReset() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await auth.resetPassword(email: email, redirectTo: redirectScheme)
            errorMessage = nil
            infoMessage = "Enviamos un enlace a tu correo. Sigue las instrucciones para crear una nueva contraseña."
        } catch {
            infoMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}

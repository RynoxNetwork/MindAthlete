import Supabase
import SwiftUI

struct SupabaseEmailAuthView: View {
    @ObservedObject var supaAuth: SupabaseAuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isProcessing: Bool = false
    @State private var alertMessage: String?
    @State private var statusMessage: String?
    @State private var isShowingForgotPassword = false
    @FocusState private var focusedField: Field?

    let onAuthenticated: (Supabase.User?, String) -> Void

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MASpacing.xl) {
                VStack(alignment: .leading, spacing: MASpacing.sm) {
                    MATypography.title("Accede a MindAthlete")
                    MATypography.body("Inicia sesión con tu correo universitario para continuar.")
                }

                VStack(spacing: MASpacing.md) {
                    TextField("Correo electrónico", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(MAColorPalette.surface))
                        .focused($focusedField, equals: .email)

                    SecureField("Contraseña", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(MAColorPalette.surface))
                        .focused($focusedField, equals: .password)
                }

                if let statusMessage {
                    MATypography.caption(statusMessage)
                        .foregroundColor(MAColorPalette.textSecondary)
                }

                VStack(spacing: MASpacing.md) {
                    MAButton(isProcessing ? "Creando cuenta..." : "Crear cuenta") {
                        Task { await handleAuthentication(.signUp) }
                    }
                    .disabled(isProcessing)

                    MAButton(isProcessing ? "Iniciando..." : "Entrar", style: .secondary) {
                        Task { await handleAuthentication(.signIn) }
                    }
                    .disabled(isProcessing)

                    Button("¿Olvidaste tu contraseña?") {
                        isShowingForgotPassword = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MAColorPalette.primary)
                    .padding(.top, MASpacing.sm)

#if canImport(GoogleSignIn)
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("o continúa con")
                            .font(.footnote)
                            .foregroundColor(MAColorPalette.textSecondary)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }

                    Button {
                        startGoogleSignIn()
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text(isProcessing ? "Conectando..." : "Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MASpacing.sm)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
#endif
                }
            }
            .padding(MASpacing.xl)
        }
        .background(Color.maBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { focusedField = nil }
            }
        }
        .alert("Error", isPresented: alertBinding, actions: {
            Button("Entendido", role: .cancel) { alertMessage = nil }
        }, message: {
            if let alertMessage { Text(alertMessage) }
        })
        .sheet(isPresented: $isShowingForgotPassword) {
            ForgotPasswordView(auth: supaAuth) {
                isShowingForgotPassword = false
            }
        }
    }

    private enum AuthAction {
        case signUp
        case signIn
    }

    private func handleAuthentication(_ action: AuthAction) async {
        guard isValidInput else {
            alertMessage = "Ingresa un correo y contraseña válidos."
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            switch action {
            case .signUp:
                try await supaAuth.signUp(email: email, password: password)
                statusMessage = "Revisa tu bandeja para confirmar el registro si es necesario."
            case .signIn:
                try await supaAuth.signIn(email: email, password: password)
                statusMessage = "Sesión iniciada correctamente."
            }
            focusedField = nil
            onAuthenticated(supaAuth.user, "supabase_email")
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private var isValidInput: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

#if canImport(GoogleSignIn)
    private func startGoogleSignIn() {
        guard !isProcessing else { return }
        isProcessing = true
        GoogleAuthBridge.signIn { idToken, accessToken in
            Task {
                do {
                    try await supaAuth.signInWithGoogle(idToken: idToken, accessToken: accessToken)
                    statusMessage = "Sesión iniciada con Google ✅"
                    onAuthenticated(supaAuth.user, "supabase_google")
                } catch {
                    alertMessage = error.localizedDescription
                }
                isProcessing = false
            }
        } onError: { error in
            alertMessage = error.localizedDescription
            isProcessing = false
        }
    }
#endif
}

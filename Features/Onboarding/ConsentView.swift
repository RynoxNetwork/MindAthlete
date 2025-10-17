
import SwiftUI

struct ConsentView: View {
    let repo: UserProfilesRepository
    var onCompleted: () -> Void

    @State private var accepted = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MASpacing.lg) {
                MATypography.title("Consentimiento informado")

                MATypography.body("""
MindAthlete recoge tus datos para brindar recomendaciones personalizadas y mejorar tu rendimiento. Al continuar aceptas:

• Tratamiento de datos personales conforme a la normativa vigente.
• Uso de tus registros para generar métricas y recomendaciones dentro de la app.
• Posible contacto del equipo MindAthlete para acompañamiento y soporte.
""")

                Toggle("Acepto los términos y autorizo el tratamiento de mis datos.", isOn: $accepted)
                    .tint(MAColorPalette.primary)

                MAButton(isSaving ? "Guardando..." : "Continuar", style: .primary) {
                    Task { await saveConsent() }
                }
                .disabled(!accepted || isSaving)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, MASpacing.sm)
                }
            }
            .padding()
        }
    }

    private func saveConsent() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await repo.updateConsent(true)
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

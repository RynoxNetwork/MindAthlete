
import SwiftUI

struct ConsentView: View {
    var onAgree: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.lg) {
            MATypography.title("Consentimiento informado")
            MATypography.body("MindAthlete cumple con estándares de privacidad universitarios. Acepta para continuar.")
            MAButton("Acepto", style: .primary, action: onAgree)
        }
        .padding()
    }
}

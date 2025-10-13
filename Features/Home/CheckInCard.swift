
import SwiftUI

struct CheckInCard: View {
    var action: () -> Void

    var body: some View {
        MACard(title: "¿Cómo te sientes?") {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                MATypography.body("Registra tu mood y energía para mantener tu foco.")
                MAButton("Registrar check-in", style: .primary, action: action)
            }
        }
    }
}


import SwiftUI

struct MeditationSessionView: View {
    var body: some View {
        VStack(spacing: MASpacing.lg) {
            MATypography.title("Meditación guiada")
            MATypography.body("Siéntate cómodo, respira y escucha tu cuerpo por 5 minutos.")
            SessionTimerView(totalSeconds: 300)
        }
        .padding()
    }
}

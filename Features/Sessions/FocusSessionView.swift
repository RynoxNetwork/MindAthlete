
import SwiftUI

struct FocusSessionView: View {
    var body: some View {
        VStack(spacing: MASpacing.lg) {
            MATypography.title("Enfoque de visualización")
            MATypography.body("Visualiza tu competencia con detalle durante 3 minutos.")
            SessionTimerView(totalSeconds: 180)
        }
        .padding()
    }
}

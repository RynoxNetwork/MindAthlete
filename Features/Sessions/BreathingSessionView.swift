
import SwiftUI

struct BreathingSessionView: View {
    var body: some View {
        VStack(spacing: MASpacing.lg) {
            MATypography.title("Respiración 4-7-8")
            MATypography.body("Inhala 4s, sostiene 7s y exhala 8s. Repite 4 veces.")
            SessionTimerView(totalSeconds: 19)
        }
        .padding()
    }
}

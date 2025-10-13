
import SwiftUI

struct FeedbackView: View {
    var onPositive: () -> Void
    var onNegative: () -> Void

    var body: some View {
        HStack(spacing: MASpacing.sm) {
            MAButton("Me ayudó", style: .secondary, action: onPositive)
            MAButton("No hoy", style: .tertiary, action: onNegative)
        }
    }
}

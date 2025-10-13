
import SwiftUI

struct DiaryChartView: View {
    let moods: [Mood]

    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            MATypography.title("Tendencia semanal")
            if moods.isEmpty {
                MATypography.body("Completa check-ins para ver tus gráficas.")
            } else {
                Rectangle()
                    .fill(MAColorPalette.primary.opacity(0.2))
                    .frame(height: 160)
                    .overlay(Text("Gráfico próximamente").foregroundColor(MAColorPalette.primary))
                    .cornerRadius(16)
            }
        }
    }
}

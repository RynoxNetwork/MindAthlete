
import SwiftUI

struct RecommendationCard: View {
    let recommendations: RecommendationResponse?

    var body: some View {
        MACard(title: "Recomendación de hoy") {
            if let recommendations {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    ForEach(recommendations.recommendations, id: \.self) { tip in
                        MATypography.body("• \(tip)")
                    }
                    if let preCompetition = recommendations.preCompetition {
                        MATypography.caption("Pre-competencia: \(preCompetition)")
                    }
                }
            } else {
                MATypography.body("Activa tu coach con IA para recibir recomendaciones personalizadas cada mañana.")
            }
        }
    }
}

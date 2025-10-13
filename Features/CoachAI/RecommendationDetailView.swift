
import SwiftUI

struct RecommendationDetailView: View {
    let recommendation: RecommendationResponse

    var body: some View {
        List {
            Section(header: Text("Recomendaciones")) {
                ForEach(recommendation.recommendations, id: \.self) { item in
                    MATypography.body(item)
                        .padding(.vertical, MASpacing.xs)
                }
            }
            if let preCompetition = recommendation.preCompetition {
                Section(header: Text("Pre-competencia")) {
                    MATypography.body(preCompetition)
                }
            }
            Section(header: Text("Racional")) {
                MATypography.body(recommendation.rationale)
            }
        }
        .navigationTitle("Detalle")
    }
}

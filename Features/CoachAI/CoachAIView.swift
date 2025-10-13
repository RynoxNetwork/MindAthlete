
import SwiftUI

struct CoachAIView: View {
    @StateObject var viewModel: CoachAIViewModel
    
    init(viewModel: CoachAIViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MASpacing.lg) {
                header
                recommendationSection
            }
            .padding(MASpacing.lg)
        }
        .background(Color.maBackground.ignoresSafeArea())
        .navigationTitle("Coach IA")
        .task {
            await viewModel.load()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            MATypography.title("Tu coach te acompaña")
            MATypography.body("Recomendaciones frescas basadas en tus check-ins, hábitos y próximos eventos.")
        }
    }
    
    private var recommendationSection: some View {
        Group {
            if let recommendations = viewModel.recommendations {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    ForEach(recommendations.recommendations.indices, id: \.self) { index in
                        MACard(title: "Recomendación #\(index + 1)") {
                            MATypography.body(recommendations.recommendations[index])
                        }
                    }
                    if let rationale = recommendations.rationale.split(separator: ".").first {
                        MACard(title: "Racional") {
                            MATypography.body(String(rationale))
                        }
                    }
                    if let preCompetition = recommendations.preCompetition {
                        MACard(title: "Pre-competencia") {
                            MATypography.body(preCompetition)
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                MACard {
                    MATypography.body("Activa tu plan y completa check-ins para recibir nuevas recomendaciones.")
                }
            }
        }
    }
}

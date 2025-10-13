
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onCompleted: () -> Void

    var body: some View {
        VStack(spacing: MASpacing.lg) {
            Spacer()
            TabView(selection: $viewModel.currentIndex) {
                ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: MASpacing.lg) {
                        Image(systemName: step.illustration)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .foregroundStyle(MAColorPalette.primary)
                            .accessibilityHidden(true)

                        MATypography.title(step.title)
                            .multilineTextAlignment(.center)

                        MATypography.body(step.description)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, MASpacing.lg)
                    }
                    .tag(index)
                    .padding(.horizontal, MASpacing.lg)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .accessibilityElement(children: .contain)

            VStack(spacing: MASpacing.md) {
                if viewModel.isLastStep {
                    MAButton("Únete al piloto (gratis)") {
                        viewModel.complete()
                        onCompleted()
                    }
                    .accessibilityHint("Avanza al registro para el piloto MindAthlete")
                } else {
                    MAButton("Continuar") {
                        viewModel.next()
                    }
                }

                Button("¿Ya tienes cuenta? Inicia sesión", action: onCompleted)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(MAColorPalette.textSecondary)
            }
            .padding(.horizontal, MASpacing.lg)
            Spacer()
        }
        .background(Color.maBackground.ignoresSafeArea())
        .animation(.easeInOut, value: viewModel.currentIndex)
    }
}

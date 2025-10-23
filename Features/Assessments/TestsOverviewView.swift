import SwiftUI

struct TestsOverviewView: View {
    @StateObject var viewModel: TestsOverviewViewModel
    var onAssessmentCompleted: (() -> Void)?

    @State private var activeInstrument: AssessmentInstrument?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MASpacing.lg) {
                overviewHeader

                if viewModel.isLoading && viewModel.rows.isEmpty {
                    skeletonCard
                } else {
                    ForEach(viewModel.rows) { row in
                        instrumentCard(for: row)
                    }
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        Task { await viewModel.refresh() }
                    }
                }

                privacyFooter
            }
            .padding(.horizontal, MASpacing.lg)
            .padding(.vertical, MASpacing.lg)
        }
        .background(Color.maBackground.ignoresSafeArea())
        .navigationDestination(item: $activeInstrument) { instrument in
            TestFlowView(
                viewModel: viewModel.makeFlowViewModel(for: instrument),
                onCompleted: { wasRetake, takenAt in
                    viewModel.trackCompletion(for: instrument, wasRetake: wasRetake, takenAt: takenAt)
                    Task { await viewModel.refresh() }
                    onAssessmentCompleted?()
                }
            )
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationTitle("Autoevaluaciones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.maBackground, for: .navigationBar)
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            Text("Autoevaluaciones")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(MAColorPalette.textPrimary)
            Text("Completa los tests recomendados para personalizar tu coach y seguir tu progreso mental.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func instrumentCard(for row: TestsOverviewViewModel.InstrumentRow) -> some View {
        MACard {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                HStack(alignment: .top, spacing: MASpacing.md) {
                    Image(systemName: row.iconName)
                        .font(.system(size: 30))
                        .foregroundStyle(MAColorPalette.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(MAColorPalette.accent.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        Text(row.title)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        Text(row.description)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(MAColorPalette.textSecondary)
                        Text(row.estimatedDuration)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(MAColorPalette.accent)
                    }
                }

                Divider()

                HStack {
                    Label(row.statusText, systemImage: row.ctaEnabled ? "checkmark.circle" : "hourglass")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(row.ctaEnabled ? MAColorPalette.primary : MAColorPalette.textSecondary)
                    Spacer()
                }

                MAButton(row.ctaTitle) {
                    guard row.ctaEnabled else { return }
                    viewModel.trackStart(for: row.instrument)
                    activeInstrument = row.instrument
                }
                .disabled(!row.ctaEnabled)
            }
        }
    }

    private var skeletonCard: some View {
        MACard {
            VStack(alignment: .leading, spacing: MASpacing.md) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.maSurfaceAlt.opacity(0.6))
                    .frame(height: 22)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.maSurfaceAlt.opacity(0.6))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.maSurfaceAlt.opacity(0.6))
                    .frame(height: 48)
            }
            .shimmer()
        }
        .accessibilityHidden(true)
    }

    private var privacyFooter: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            Divider()
            Text("Tus respuestas son privadas. Alimentan al coach de MindAthlete y ayudan a personalizar tus planes, nunca se comparten con terceros.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(MAColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: MASpacing.sm) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            MAButton("Reintentar", style: .secondary, action: onRetry)
        }
        .padding(MASpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MAColorPalette.danger)
        )
    }
}

private extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.45),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 1.4)
                    .offset(x: phase * width * 1.4)
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
                }
                .mask(content)
            )
            .onAppear {
                phase = 1
            }
    }
}

private extension Color {
    static var maSurfaceAlt: Color { Color.maSurface.opacity(0.7) }
}

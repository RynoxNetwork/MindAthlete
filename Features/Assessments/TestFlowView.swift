import SwiftUI

struct TestFlowView: View {
    @StateObject var viewModel: TestFlowViewModel
    let onCompleted: (_ wasRetake: Bool, _ takenAt: Date) -> Void

    @Environment(\.dismiss) private var dismiss

    init(viewModel: TestFlowViewModel, onCompleted: @escaping (_ wasRetake: Bool, _ takenAt: Date) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
    }

    var body: some View {
        VStack(spacing: MASpacing.lg) {
            if let summary = viewModel.summary {
                summaryContent(summary)
            } else {
                questionContent
            }
        }
        .padding(MASpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.maBackground.ignoresSafeArea())
        .navigationTitle(viewModel.instrument.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cerrar") { dismiss() }
                .font(.system(.body, design: .rounded))
        }
    }

    private var questionContent: some View {
        VStack(alignment: .leading, spacing: MASpacing.lg) {
            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text("Pregunta \(viewModel.currentIndex + 1) de \(viewModel.items.count)")
                    .font(.system(.headline, design: .rounded))
                ProgressView(value: viewModel.progress)
                    .tint(MAColorPalette.primary)
            }

            Text(viewModel.currentItem.prompt)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(MAColorPalette.textPrimary)
                .multilineTextAlignment(.leading)

            LikertScale(selection: Binding(
                get: { viewModel.answer(for: viewModel.currentIndex) },
                set: { newValue in
                    if let newValue {
                        viewModel.select(answer: newValue)
                    }
                }
            ))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(MAColorPalette.danger)
            }

            VStack(spacing: MASpacing.sm) {
                if viewModel.currentIndex > 0 {
                    MAButton("Anterior", style: .tertiary) {
                        viewModel.goBack()
                    }
                }

                MAButton(viewModel.currentIndex == viewModel.items.count - 1 ? "Enviar" : "Siguiente") {
                    if viewModel.currentIndex == viewModel.items.count - 1 {
                        Task { await viewModel.submit() }
                    } else {
                        viewModel.goNext()
                    }
                }
                .disabled(!canAdvance())
                .overlay(alignment: .center) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
            }

            Spacer()
        }
    }

    private func canAdvance() -> Bool {
        if viewModel.isSubmitting { return false }
        return viewModel.answer(for: viewModel.currentIndex) != nil
    }

    private func summaryContent(_ summary: TestFlowViewModel.Summary) -> some View {
        VStack(alignment: .leading, spacing: MASpacing.lg) {
            MACard {
                VStack(alignment: .leading, spacing: MASpacing.md) {
                    Text("Resultados")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text(summary.wasRetake ? "¡Buen trabajo! Actualizamos tus resultados." : "¡Excelente! Ya tenemos tus respuestas.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(MAColorPalette.textSecondary)

                    ForEach(summary.subscales) { subscale in
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            HStack {
                                Text(subscale.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Spacer()
                                Text("\(Int(subscale.normalized))%")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(MAColorPalette.textSecondary)
                            }
                            ProgressView(value: subscale.normalized, total: 100)
                                .tint(MAColorPalette.primary)
                        }
                    }

                    Divider()

                    Text("Puntaje global: \(Int(summary.overallScore))%")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(MAColorPalette.textPrimary)
                }
            }

            MAButton("Volver a Tests") {
                onCompleted(summary.wasRetake, summary.takenAt)
                dismiss()
            }

            Spacer()
        }
    }
}

private struct LikertScale: View {
    @Binding var selection: Int?
    private let options = 1...5

    var body: some View {
        HStack(spacing: MASpacing.sm) {
            ForEach(options, id: \.self) { value in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        selection = value
                    }
                } label: {
                    Text("\(value)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MASpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection == value ? MAColorPalette.primary : Color.maSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MAColorPalette.primary.opacity(selection == value ? 0 : 0.2), lineWidth: 1)
                        )
                        .foregroundStyle(selection == value ? Color.white : MAColorPalette.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Opción \(value)")
            }
        }
        .padding(.vertical, MASpacing.sm)
    }
}

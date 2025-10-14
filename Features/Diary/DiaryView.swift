import SwiftUI

struct DiaryView: View {
    @StateObject var viewModel: DiaryViewModel
    
    init(viewModel: DiaryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        List {
            Section(header: MASectionHeader(title: "Historial reciente")) {
                if viewModel.moods.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.moods) { mood in
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text(mood.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(MAColorPalette.textPrimary)
                            MATypography.body("Ánimo: \(mood.score)/10 · Energía: \(mood.energy)/10")
                            if !mood.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(mood.tags, id: \.self) { tag in
                                            MAChip(tag)
                                        }
                                    }
                                }
                            }
                            if let notes = mood.notes {
                                MATypography.caption(notes)
                            }
                        }
                        .padding(.vertical, MASpacing.sm)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Diario")
        .background(Color.maBackground)
        .task {
            await viewModel.load()
        }
    }
    
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MASpacing.sm) {
            MATypography.body("Registra tu primer check-in para ver tu evolución emocional.")
            MAButton("Registrar ahora", style: .primary) {
                // Trigger creation flow
            }
        }
        .padding(.vertical, MASpacing.lg)
    }
}

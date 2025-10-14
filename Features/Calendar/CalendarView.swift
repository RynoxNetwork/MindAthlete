import SwiftUI

struct CalendarView: View {
    @StateObject var viewModel: CalendarViewModel

    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: MASectionHeader(title: "Próximos eventos", actionTitle: "Nuevo", action: {})) {
                if viewModel.events.isEmpty {
                    MATypography.body("Agrega competencias, entrenos y exámenes para preparar tus rituales.")
                        .padding(.vertical, MASpacing.lg)
                } else {
                    ForEach(viewModel.events) { event in
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text(event.type)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(MAColorPalette.textPrimary)
                            MATypography.caption(event.date.formatted(date: .complete, time: .omitted))
                            MATypography.caption("Importancia: \(event.importance)/5")
                        }
                        .padding(.vertical, MASpacing.sm)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Calendario")
        .task {
            await viewModel.load()
        }
    }
}

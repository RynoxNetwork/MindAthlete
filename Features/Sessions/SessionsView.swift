
import SwiftUI

struct SessionsView: View {
    @StateObject var viewModel: SessionsViewModel

    init(viewModel: SessionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: MASectionHeader(title: "Sesiones guiadas")) {
                sessionRow(icon: "lungs.fill", title: "Respiración 4-7-8", description: "Regula tu sistema nervioso antes de competir.")
                sessionRow(icon: "square.grid.2x2", title: "Box Breathing", description: "Encuentra foco en 4 minutos.")
                sessionRow(icon: "sparkles", title: "Meditación breve", description: "Recarga mental con visualización." )
                sessionRow(icon: "bolt.fill", title: "Enfoque pre-competencia", description: "Activa tu protocolo mental.")
            }

            Section(header: MASectionHeader(title: "Tu registro")) {
                if viewModel.sessions.isEmpty {
                    MATypography.body("Aún no has registrado sesiones. Prueba una hoy.")
                        .padding(.vertical, MASpacing.lg)
                } else {
                    ForEach(viewModel.sessions) { session in
                        VStack(alignment: .leading, spacing: MASpacing.xs) {
                            Text(session.type)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(MAColorPalette.textPrimary)
                            MATypography.caption("Duración: \(session.durationMin) min")
                        }
                        .padding(.vertical, MASpacing.sm)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sesiones")
        .task {
            await viewModel.load()
        }
    }

    private func sessionRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: MASpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(MAColorPalette.primary)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: MASpacing.xs) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(MAColorPalette.textPrimary)
                MATypography.caption(description)
            }
            Spacer()
            MAButton("Iniciar", style: .secondary) {}
                .frame(maxWidth: 100)
        }
        .padding(.vertical, MASpacing.sm)
    }
}

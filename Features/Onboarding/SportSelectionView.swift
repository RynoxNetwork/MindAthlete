
import SwiftUI

struct SportSelectionView: View {
    @Binding var selectedSport: String
    private let sports = ["Atletismo", "Natación", "Fútbol", "Vóley", "Basket"]

    var body: some View {
        List(sports, id: \.self) { sport in
            HStack {
                Text(sport)
                Spacer()
                if sport == selectedSport {
                    Image(systemName: "checkmark")
                        .foregroundColor(MAColorPalette.primary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedSport = sport }
        }
        .navigationTitle("Tu deporte")
    }
}

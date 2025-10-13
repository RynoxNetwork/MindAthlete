
import SwiftUI

struct PlanView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MASpacing.md) {
            MATypography.title("Planes MindAthlete")
            MATypography.body("El piloto es gratuito. Pronto podrás desbloquear IA avanzada y reportes con RevenueCat.")
            MAButton("Ver planes") {}
        }
        .padding()
    }
}

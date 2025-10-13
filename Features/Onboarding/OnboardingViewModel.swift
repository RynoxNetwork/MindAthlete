
import Combine
import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let illustration: String
    }

    @Published var currentIndex: Int = 0
    let steps: [Step]
    private let authService: AuthServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    init(authService: AuthServiceProtocol, analytics: AnalyticsServiceProtocol) {
        self.authService = authService
        self.analytics = analytics
        self.steps = [
            Step(title: "Entrena tu mente", description: "Únete al piloto y descubre cómo MindAthlete te acompaña en tu rendimiento y bienestar.", illustration: "sparkles"),
            Step(title: "Diario emocional", description: "Registra tus moods y energía en segundos, con seguimiento semanal y analítica clara.", illustration: "heart.text.square"),
            Step(title: "Hábitos y sesiones", description: "Crea hábitos saludables y practica ejercicios guiados para foco, calma y recuperación.", illustration: "figure.run.square.stack"),
            Step(title: "Coach con IA", description: "Recibe recomendaciones personalizadas cada día, basadas en tus datos y próximos retos.", illustration: "brain.head.profile")
        ]
    }

    var isLastStep: Bool {
        currentIndex == steps.count - 1
    }

    func next() {
        guard currentIndex < steps.count - 1 else { return }
        currentIndex += 1
        analytics.track(event: AnalyticsEvent(name: "onboarding_step", parameters: ["index": currentIndex]))
    }

    func complete() {
        analytics.track(event: AnalyticsEvent(name: "onboarding_completed", parameters: [:]))
    }
}

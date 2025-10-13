
import SwiftUI

struct SessionTimerView: View {
    let totalSeconds: Int
    @State private var remainingSeconds: Int
    @State private var timer: Timer?

    init(totalSeconds: Int) {
        self.totalSeconds = totalSeconds
        _remainingSeconds = State(initialValue: totalSeconds)
    }

    var body: some View {
        VStack(spacing: MASpacing.md) {
            Text(formatTime(remainingSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(MAColorPalette.accent)
            MAButton(remainingSeconds == totalSeconds ? "Iniciar" : "Reiniciar", style: .secondary) {
                start()
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func start() {
        timer?.invalidate()
        remainingSeconds = totalSeconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                t.invalidate()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

import SwiftUI

@main
struct MindAthleteApp: App {
    @StateObject private var appState = AppState()
    private let environment = AppEnvironment.live()
    #if DEBUG
    @State private var isShowingDebugConnect = false
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            ZStack(alignment: .bottomTrailing) {
                root
                Button {
                    isShowingDebugConnect = true
                } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.title3)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .padding()
                        .accessibilityLabel("Abrir verificación Supabase")
                }
            }
            .sheet(isPresented: $isShowingDebugConnect) {
                DebugConnectView()
            }
            #else
            root
            #endif
        }
    }

    private var root: some View {
        RootView(appState: appState, environment: environment)
            .environmentObject(appState)
    }
}

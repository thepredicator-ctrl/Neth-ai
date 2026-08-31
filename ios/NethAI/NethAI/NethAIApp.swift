import SwiftUI

@main
struct NethAIApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isSignedIn {
                RootView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            } else {
                LoginView()
                    .environmentObject(authService)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

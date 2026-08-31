import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - NethUser
struct NethUser: Identifiable, Codable, Sendable {
    let id: String            // Apple ID identifier (stable across devices)
    let displayName: String
    let email: String?
    let signedInAt: Date
    let isGuest: Bool
}

// MARK: - AuthError
enum AuthError: LocalizedError {
    case cancelled
    case failed(String)
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .failed(let m): return m
        case .notAvailable: return "Sign in with Apple is not available. This build may need a proper signing certificate."
        }
    }
}

// MARK: - AuthService
// Manages Sign in with Apple + iCloud key-value store persistence.
// Falls back to UserDefaults if iCloud KV store is unavailable (unsigned builds).
@MainActor
final class AuthService: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var currentUser: NethUser?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let userDefaultsKey = "ai.neth.NethAI.currentUser"
    private let iCloudKey = "ai.neth.NethAI.currentUser"

    override init() {
        super.init()
        loadUser()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: Persistence

    private func loadUser() {
        // Try iCloud KV store first (syncs across devices)
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: iCloudKey),
           let user = try? JSONDecoder().decode(NethUser.self, from: data) {
            self.currentUser = user
            return
        }
        // Fall back to local UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(NethUser.self, from: data) {
            self.currentUser = user
        }
    }

    private func saveUser(_ user: NethUser?) {
        let data = try? JSONEncoder().encode(user)
        // Save to UserDefaults (local)
        if let data {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
        // Save to iCloud KV store (syncs across devices with same Apple ID)
        NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: Sign in with Apple

    func signInWithApple() {
        isLoading = true
        error = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signInAsGuest() {
        let guest = NethUser(
            id: "guest-\(UUID().uuidString)",
            displayName: "Guest",
            email: nil,
            signedInAt: Date(),
            isGuest: true
        )
        self.currentUser = guest
        saveUser(guest)
    }

    func signOut() {
        self.currentUser = nil
        saveUser(nil)
    }

    // MARK: ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            self.isLoading = false

            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let displayName: String
                if let fullName = credential.fullName {
                    let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }.filter { !$0.isEmpty }
                    displayName = parts.isEmpty ? "Neth-AI User" : parts.joined(separator: " ")
                } else {
                    displayName = "Neth-AI User"
                }

                let user = NethUser(
                    id: credential.user,
                    displayName: displayName,
                    email: credential.email,
                    signedInAt: Date(),
                    isGuest: false
                )
                self.currentUser = user
                self.saveUser(user)
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            if let asErr = error as? ASAuthorizationError, asErr.code == .canceled {
                self.error = nil // silent on cancel
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the first window scene's main window.
        // This is called on the main thread by the system, so it's safe to access UIKit here.
        if Thread.isMainThread {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
        // Fallback: dispatch sync to main thread
        return DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

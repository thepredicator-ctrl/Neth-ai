import Foundation
import AuthenticationServices
import SwiftUI
import os.log

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
    case unsignedBuild

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .failed(let m): return m
        case .notAvailable: return "Sign in with Apple is not available on this device."
        case .unsignedBuild:
            return "This IPA is unsigned. Sign in with Apple requires a valid Apple Developer certificate. Use 'Continue as Guest' instead."
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
    @Published var signInWithAppleAvailable: Bool = false

    // CRITICAL: retain the controller for the duration of the sign-in flow.
    // If it's deallocated mid-flow, the ASAuthorizationController sheet
    // dismisses silently and the user sees "nothing happened".
    private var currentController: ASAuthorizationController?

    private let logger = Logger(subsystem: "ai.neth.NethAI", category: "AuthService")
    private let userDefaultsKey = "ai.neth.NethAI.currentUser"
    private let iCloudKey = "ai.neth.NethAI.currentUser"

    override init() {
        super.init()
        // Detect signing status: Sign in with Apple only works on properly signed builds
        signInWithAppleAvailable = CodeSigningChecker.hasSignInWithAppleEntitlement
        logger.info("Sign in with Apple available: \(self.signInWithAppleAvailable)")
        loadUser()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: Persistence

    private func loadUser() {
        // Try iCloud KV store first (syncs across devices) — only works on signed builds
        if CodeSigningChecker.hasICloudEntitlement,
           let data = NSUbiquitousKeyValueStore.default.data(forKey: iCloudKey),
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
        // Save to UserDefaults (local — always works)
        if let data {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
        // Save to iCloud KV store (only if entitlement is present)
        if CodeSigningChecker.hasICloudEntitlement {
            NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    // MARK: Sign in with Apple

    func signInWithApple() {
        // Pre-check: is Sign in with Apple actually available on this build?
        if !signInWithAppleAvailable {
            let reason = CodeSigningChecker.signInWithAppleUnavailableReason ?? "Sign in with Apple is not available."
            logger.error("Sign in with Apple unavailable: \(reason)")
            self.error = reason
            return
        }

        isLoading = true
        error = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        // CRITICAL: retain the controller so it doesn't get deallocated mid-flow
        self.currentController = controller
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

    func clearError() {
        self.error = nil
    }

    // MARK: ASAuthorizationControllerDelegate

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            self.isLoading = false
            self.currentController = nil

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
                self.logger.info("Sign in with Apple succeeded for user: \(user.id)")
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            self.currentController = nil

            // Map the error to a user-friendly message
            if let asErr = error as? ASAuthorizationError {
                switch asErr.code {
                case .canceled:
                    // User cancelled — silent
                    self.error = nil
                    self.logger.info("Sign in with Apple cancelled by user")
                case .failed:
                    self.error = "Sign in with Apple failed. This usually means the app is not properly signed with an Apple Developer certificate. Use 'Continue as Guest' instead, or sign the IPA with your own developer account."
                    self.logger.error("ASAuthorizationError.failed: \(error.localizedDescription)")
                case .notHandled:
                    self.error = "Sign in with Apple request was not handled. Please try again."
                case .notInteractive:
                    self.error = "Sign in with Apple cannot be shown right now. Please try again."
                case .unknown:
                    self.error = "Sign in with Apple failed with an unknown error. The app may not be properly signed. Use 'Continue as Guest' instead."
                    self.logger.error("ASAuthorizationError.unknown: \(error.localizedDescription)")
                @unknown default:
                    self.error = "Sign in with Apple failed: \(error.localizedDescription)"
                }
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Called on main thread by the system.
        if Thread.isMainThread {
            return Self.findKeyWindow() ?? ASPresentationAnchor()
        }
        // Fallback: dispatch sync to main thread
        var anchor = ASPresentationAnchor()
        DispatchQueue.main.sync {
            anchor = Self.findKeyWindow() ?? ASPresentationAnchor()
        }
        return anchor
    }

    nonisolated private static func findKeyWindow() -> ASPresentationAnchor? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.isKeyWindow {
                return window
            }
            if let first = windowScene.windows.first {
                return first
            }
        }
        return nil
    }
}

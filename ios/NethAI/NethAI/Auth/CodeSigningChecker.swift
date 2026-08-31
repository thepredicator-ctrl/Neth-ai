import Foundation
import os.log

// MARK: - CodeSigningChecker
// Detects whether the app is properly signed or running as an unsigned/sideloaded build.
// Sign in with Apple requires a valid signing certificate, so we use this to gracefully
// degrade the UX on unsigned builds.
//
// On iOS, we can't directly inspect entitlements at runtime (unlike macOS with SecStaticCode).
// Instead, we check for the presence of an embedded provisioning profile, which only exists
// in properly signed builds (Development, AdHoc, or App Store distribution).

enum CodeSigningChecker {
    private static let logger = Logger(subsystem: "ai.neth.NethAI", category: "CodeSigning")

    /// Returns true if the app appears to be properly signed (has a provisioning profile).
    /// Unsigned builds built with CODE_SIGNING_ALLOWED=NO do not have embedded.mobileprovision.
    static var isProperlySigned: Bool {
        let provisionPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
        let signed = provisionPath != nil
        logger.debug("embedded.mobileprovision present: \(signed)")
        return signed
    }

    /// Returns true if Sign in with Apple is likely available.
    /// On iOS, we approximate this by checking for a provisioning profile.
    /// The actual entitlement check happens when the user taps the button — if it fails,
    /// we show a clear error message.
    static var hasSignInWithAppleEntitlement: Bool {
        // We can't read entitlements directly on iOS, but we can check if the app is signed.
        // If it's signed, the entitlements from our .entitlements file are applied.
        // If it's unsigned, no entitlements are applied.
        return isProperlySigned
    }

    /// Returns true if iCloud KV store is likely available.
    static var hasICloudEntitlement: Bool {
        return isProperlySigned
    }

    /// Human-readable summary of why Sign in with Apple might fail.
    static var signInWithAppleUnavailableReason: String? {
        if !isProperlySigned {
            return "This IPA is unsigned. Sign in with Apple requires a valid Apple Developer certificate.\n\nTo use Sign in with Apple, sign the IPA with your own Apple Developer account (Development or AdHoc). Guest mode works without signing."
        }
        return nil
    }
}

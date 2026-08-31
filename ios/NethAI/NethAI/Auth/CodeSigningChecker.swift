import Foundation
import Security
import os.log

// MARK: - CodeSigningChecker
// Detects whether the app is properly signed (with entitlements applied) or
// running as an unsigned/sideloaded build. Sign in with Apple requires a valid
// signing certificate, so we use this to gracefully degrade the UX on unsigned builds.

enum CodeSigningChecker {
    private static let logger = Logger(subsystem: "ai.neth.NethAI", category: "CodeSigning")

    /// Returns true if the Sign in with Apple entitlement is actually applied at runtime.
    /// On unsigned builds (CODE_SIGNING_ALLOWED=NO), entitlements are not applied, so this returns false.
    static var hasSignInWithAppleEntitlement: Bool {
        guard let entitlements = currentEntitlements else {
            return false
        }
        return entitlements["com.apple.developer.applesignin"] != nil
    }

    /// Returns true if iCloud KV store entitlement is present.
    static var hasICloudEntitlement: Bool {
        guard let entitlements = currentEntitlements else {
            return false
        }
        return entitlements["com.apple.developer.ubiquity-kvstore-identifier"] != nil
    }

    /// The current app's runtime entitlements (as applied by the code signature).
    /// Returns nil for unsigned builds where entitlements aren't applied.
    static var currentEntitlements: [String: Any]? {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            [],
            &staticCode
        )
        guard status == errSecSuccess, let code = staticCode else {
            logger.debug("SecStaticCodeCreateWithPath failed: \(status)")
            return nil
        }

        var signingInfo: CFDictionary?
        let reqStatus = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        guard reqStatus == errSecSuccess, let infoDict = signingInfo as? [String: Any] else {
            logger.debug("SecCodeCopySigningInformation failed: \(reqStatus)")
            return nil
        }

        // Entitlements are under "entitlements" key when kSecCSSigningInformation is requested
        if let ents = infoDict["entitlements"] as? [String: Any] {
            return ents
        }
        // Also check "EntitlementsPlainFile" or just return empty
        logger.debug("No entitlements found in signing info. Keys: \(infoDict.keys.sorted().joined(separator: ", "))")
        return nil
    }

    /// Human-readable summary of why Sign in with Apple might fail.
    static var signInWithAppleUnavailableReason: String? {
        if !hasSignInWithAppleEntitlement {
            return "This IPA is unsigned. Sign in with Apple requires a valid Apple Developer certificate to be applied at runtime.\n\nTo use Sign in with Apple, sign the IPA with your own Apple Developer account using codesign, Sideloadly, or AltStore. Guest mode works without signing."
        }
        return nil
    }
}

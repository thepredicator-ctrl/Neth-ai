import SwiftUI
import AuthenticationServices

// MARK: - LoginView
// First screen. Black + glowing orange Neth-AI identity.
// On properly signed builds: shows Sign in with Apple button.
// On unsigned/sideloaded builds: shows a notice + prominent Guest mode.

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var animateOrb = false
    @State private var showSigningNotice = false

    var body: some View {
        ZStack {
            NethBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Orb
                    VStack(spacing: 20) {
                        NethOrbView(state: .idle, size: 180)
                            .scaleEffect(animateOrb ? 1.0 : 0.92)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateOrb)

                        VStack(spacing: 8) {
                            Text("NETH-AI")
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(NethTheme.textPrimary)
                                .tracking(8)

                            Text("Your local AI appliance.")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(NethTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer(minLength: 50)

                    // Sign in section
                    VStack(spacing: 14) {
                        if authService.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(NethTheme.orange)
                                    .scaleEffect(1.2)
                                Text("Signing in…")
                                    .font(.caption)
                                    .foregroundStyle(NethTheme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            // Sign in with Apple button — only shown on properly signed builds
                            if authService.signInWithAppleAvailable {
                                Button {
                                    authService.signInWithApple()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 18, weight: .bold))
                                        Text("Sign in with Apple")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: 340)
                                    .frame(height: 54)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.white, Color(white: 0.92)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(NethTheme.orange.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: NethTheme.orange.opacity(0.15), radius: 12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Unsigned build notice
                                VStack(spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(NethTheme.amber)
                                        Text("Unsigned build")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(NethTheme.amber)
                                    }
                                    Text("Sign in with Apple requires a signed IPA.\nContinue as Guest to use Neth-AI.")
                                        .font(.caption)
                                        .foregroundStyle(NethTheme.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(NethTheme.amber.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(NethTheme.amber.opacity(0.2), lineWidth: 1)
                                )
                                .frame(maxWidth: 340)
                            }

                            // Guest mode — always available
                            Button {
                                authService.signInAsGuest()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Continue as Guest")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(NethTheme.textPrimary)
                                .frame(maxWidth: 340)
                                .frame(height: 48)
                                .background(NethTheme.charcoal)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(NethTheme.hairline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            // On signed builds, show a smaller "why guest?" link
                            if authService.signInWithAppleAvailable {
                                Button {
                                    showSigningNotice = true
                                } label: {
                                    Text("Why continue as guest?")
                                        .font(.caption2)
                                        .foregroundStyle(NethTheme.textTertiary)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let err = authService.error {
                            VStack(spacing: 8) {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(NethTheme.errorGlow)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                if !authService.signInWithAppleAvailable {
                                    Button {
                                        authService.signInAsGuest()
                                    } label: {
                                        Text("Use Guest Mode")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(NethTheme.orange, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 8)

                    Spacer(minLength: 30)

                    Text("By continuing, you agree that Neth-AI runs entirely\non-device. No data leaves your device.")
                        .font(.caption2)
                        .foregroundStyle(NethTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            animateOrb = true
        }
        .alert("About Guest Mode", isPresented: $showSigningNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Guest mode stores your session locally on this device only. Sign in with Apple syncs your session across your Apple devices via iCloud. Both modes have full access to all Neth-AI features.")
        }
    }
}

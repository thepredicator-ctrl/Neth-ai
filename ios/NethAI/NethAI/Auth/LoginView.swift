import SwiftUI
import AuthenticationServices

// MARK: - LoginView
// First screen. Black + glowing orange Neth-AI identity.
// Sign in with Apple button + guest fallback (for unsigned/sideloaded builds
// where Sign in with Apple requires a proper signing certificate).

struct LoginView: View {
    @StateObject private var authService = AuthService()
    @State private var animateOrb = false

    var body: some View {
        ZStack {
            NethBackground()

            VStack(spacing: 0) {
                Spacer()

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

                Spacer()

                // Sign in section
                VStack(spacing: 14) {
                    if authService.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(NethTheme.orange)
                            Text("Signing in…")
                                .font(.caption)
                                .foregroundStyle(NethTheme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Custom Neth-AI styled Sign in with Apple button
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

                        Button {
                            authService.signInAsGuest()
                        } label: {
                            Text("Continue as Guest")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(NethTheme.textSecondary)
                                .frame(maxWidth: 340)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }

                    if let err = authService.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(NethTheme.errorGlow)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 8)

                Spacer()

                Text("By continuing, you agree that Neth-AI runs entirely\non-device. No data leaves your device.")
                    .font(.caption2)
                    .foregroundStyle(NethTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            animateOrb = true
        }
    }
}

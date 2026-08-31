import SwiftUI
import AuthenticationServices

// MARK: - LoginView — Audi Red / Silver / Grey theme
// Premium automotive aesthetic. Crystal-clear about Sign in with Apple:
// on unsigned builds it CANNOT work, so we don't show a broken button.

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var animateOrb = false

    var body: some View {
        ZStack {
            // Audi-style metallic background
            LinearGradient(
                colors: [
                    Color(hex: 0x0A0A0A),
                    Color(hex: 0x1A1A1A),
                    Color(hex: 0x0A0A0A)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle red ambient glow at top
            RadialGradient(
                colors: [NethTheme.orange.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 70)

                    // Orb
                    VStack(spacing: 24) {
                        NethOrbView(state: .idle, size: 180)
                            .scaleEffect(animateOrb ? 1.0 : 0.94)
                            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: animateOrb)

                        VStack(spacing: 6) {
                            Text("NETH-AI")
                                .font(.system(size: 38, weight: .heavy, design: .default))
                                .foregroundStyle(NethTheme.textPrimary)
                                .tracking(10)

                            // Silver underline accent
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [NethTheme.silverBright, NethTheme.silverDark],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: 60, height: 2)

                            Text("Local AI. Engineered.")
                                .font(.system(size: 14, weight: .light, design: .default))
                                .foregroundStyle(NethTheme.textSecondary)
                                .tracking(2)
                                .padding(.top, 4)
                        }
                    }

                    Spacer(minLength: 60)

                    // Sign in section
                    VStack(spacing: 16) {
                        if authService.isLoading {
                            VStack(spacing: 14) {
                                ProgressView()
                                    .tint(NethTheme.orange)
                                    .scaleEffect(1.2)
                                Text("Signing in…")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(NethTheme.textSecondary)
                                    .tracking(1)
                            }
                            .padding(.vertical, 10)
                        } else {
                            // Sign in with Apple — only on signed builds
                            if authService.signInWithAppleAvailable {
                                Button {
                                    authService.signInWithApple()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 18, weight: .bold))
                                        Text("Sign in with Apple")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: 340)
                                    .frame(height: 54)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.white, Color(white: 0.88)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(NethTheme.silverDark.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Unsigned build — clear explanation
                                VStack(spacing: 14) {
                                    VStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.shield.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(NethTheme.amber)
                                            Text("UNSIGNED BUILD")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(NethTheme.amber)
                                                .tracking(2)
                                        }
                                        Text("Sign in with Apple requires a signed IPA\nwith an Apple Developer certificate.")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(NethTheme.textTertiary)
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(2)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                    .background(NethTheme.panelMetal)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(NethTheme.amber.opacity(0.25), lineWidth: 1)
                                    )
                                    .frame(maxWidth: 340)
                                }
                            }

                            // Guest mode — primary CTA on unsigned, secondary on signed
                            Button {
                                authService.signInAsGuest()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Continue as Guest")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(NethTheme.textPrimary)
                                .frame(maxWidth: 340)
                                .frame(height: 54)
                                .background(
                                    authService.signInWithAppleAvailable
                                        ? AnyView(NethTheme.charcoalRaised)
                                        : AnyView(
                                            LinearGradient(
                                                colors: [NethTheme.orangeBright, NethTheme.orange, NethTheme.orangeDeep],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            authService.signInWithAppleAvailable
                                                ? NethTheme.hairline
                                                : NethTheme.orangeBright,
                                            lineWidth: 1
                                        )
                                )
                                .shadow(
                                    color: authService.signInWithAppleAvailable
                                        ? .clear
                                        : NethTheme.orange.opacity(0.4),
                                    radius: 14, y: 4
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let err = authService.error {
                            VStack(spacing: 10) {
                                Text(err)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(NethTheme.errorGlow)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                if !authService.signInWithAppleAvailable {
                                    Button {
                                        authService.signInAsGuest()
                                    } label: {
                                        Text("Use Guest Mode")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(NethTheme.orange, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 8)

                    Spacer(minLength: 40)

                    VStack(spacing: 4) {
                        Text("Neth-AI runs entirely on-device.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NethTheme.textTertiary)
                            .tracking(0.5)
                        Text("No data leaves your device.")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(NethTheme.textTertiary)
                            .tracking(0.5)
                    }
                    .padding(.bottom, 28)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            animateOrb = true
        }
    }
}

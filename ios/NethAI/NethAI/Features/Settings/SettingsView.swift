import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var authService = AuthService()
    @State private var localAPIEnabled = false
    @State private var pcServerHost: String = ""
    @State private var pcServerPort: String = "11434"

    var body: some View {
        NavigationStack {
            ZStack {
                NethTheme.voidBlack.ignoresSafeArea()

                List {
                    // Account section
                    Section {
                        if let user = authService.currentUser {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [NethTheme.orangeBright, NethTheme.orangeDeep],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: 44, height: 44)
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(NethTheme.textPrimary)
                                    Text(user.isGuest ? "Guest account" : (user.email ?? "Apple ID"))
                                        .font(.caption)
                                        .foregroundStyle(NethTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)

                            Button(role: .destructive) {
                                authService.signOut()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Sign Out")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        sectionHeader("Account")
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)

                    Section {
                        row("Backend", value: "llama.cpp (SwiftLlama)")
                        row("Metal acceleration", value: appState.llmEngine.metalAccelerated ? "Enabled" : "Off")
                        row("Context size", value: "\(appState.llmEngine.contextSize)")
                        row("Loaded model", value: appState.llmEngine.loadedModelName ?? "—")
                    } header: {
                        sectionHeader("Engine")
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)

                    Section {
                        Toggle("Enable local API (Ollama-style)", isOn: $localAPIEnabled)
                            .tint(NethTheme.orange)
                            .onChange(of: localAPIEnabled) { _, v in
                                appState.localAPIEnabled = v
                                Task {
                                    if v {
                                        try? await LocalAPIServer.shared.start(port: appState.localAPIPort)
                                    } else {
                                        await LocalAPIServer.shared.stop()
                                    }
                                }
                            }
                        row("API port", value: "\(appState.localAPIPort)")
                        row("Endpoint", value: "http://127.0.0.1:\(appState.localAPIPort)/api/*")
                    } header: {
                        sectionHeader("Local API")
                    } footer: {
                        Text("Exposes /api/tags, /api/generate, /api/chat, /api/show on this device. Listens only on 127.0.0.1 by default — never exposed publicly.")
                            .font(.caption2)
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)

                    Section {
                        TextField("PC server host (e.g. 192.168.1.10)", text: $pcServerHost)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                        TextField("PC server port", text: $pcServerPort)
                            .keyboardType(.numberPad)
                        Toggle("Use PC server for inference", isOn: Binding(
                            get: { appState.pcServerEnabled },
                            set: { appState.pcServerEnabled = $0 }
                        ))
                        .tint(NethTheme.orange)
                    } header: {
                        sectionHeader("PC Server Mode (optional)")
                    } footer: {
                        Text("Connect this iPad to a Neth-AI PC on the same Wi-Fi. The PC handles inference; the iPad is the interface.")
                            .font(.caption2)
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)

                    Section {
                        if let s = appState.inferenceStats {
                            row("Last tok/s", value: String(format: "%.1f", s.tokensPerSecond))
                            row("Last TTFT", value: String(format: "%.2fs", s.timeToFirstToken))
                            row("Last tokens", value: "\(s.totalTokens)")
                            row("Memory", value: String(format: "%.1f MB", s.memoryResidentMB))
                        } else {
                            Text("Run a generation to see live stats.")
                                .foregroundStyle(NethTheme.textSecondary)
                                .font(.caption)
                        }
                    } header: {
                        sectionHeader("Performance")
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)

                    Section {
                        row("App", value: "Neth-AI")
                        row("Version", value: "0.3.0")
                        row("Engine", value: "llama.cpp")
                        row("Platforms", value: "iPadOS / iOS 17+")
                    } header: {
                        sectionHeader("About")
                    }
                    .listRowBackground(NethTheme.charcoal.opacity(0.4))
                    .listRowSeparatorTint(NethTheme.hairline)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                localAPIEnabled = appState.localAPIEnabled
                pcServerHost = appState.pcServerHost
                pcServerPort = "\(appState.pcServerPort)"
            }
        }
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s)
            .textCase(.uppercase)
            .font(.caption.weight(.bold))
            .foregroundStyle(NethTheme.orange)
    }

    @ViewBuilder
    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(NethTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(NethTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

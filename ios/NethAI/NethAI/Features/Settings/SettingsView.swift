import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var localAPIEnabled = false
    @State private var pcServerHost: String = ""
    @State private var pcServerPort: String = "11434"

    var body: some View {
        NavigationStack {
            List {
                Section("Engine") {
                    LabeledContent("Backend", value: "llama.cpp (SwiftLlama)")
                    LabeledContent("Metal acceleration", value: appState.llmEngine.metalAccelerated ? "Enabled" : "Off")
                    LabeledContent("Context size", value: "\(appState.llmEngine.contextSize)")
                    if let m = appState.llmEngine.loadedModelName {
                        LabeledContent("Loaded", value: m)
                    } else {
                        LabeledContent("Loaded", value: "—")
                    }
                }

                Section {
                    Toggle("Enable local API (Ollama-style)", isOn: $localAPIEnabled)
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
                    LabeledContent("API port", value: "\(appState.localAPIPort)")
                    LabeledContent("Endpoint", value: "http://127.0.0.1:\(appState.localAPIPort)/api/*")
                } header: {
                    Text("Local API")
                } footer: {
                    Text("Exposes /api/tags, /api/generate, /api/chat, /api/show on this device. Listens only on 127.0.0.1 by default — never exposed publicly.")
                }

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
                } header: {
                    Text("PC Server Mode (optional)")
                } footer: {
                    Text("Connect this iPad to a Neth-AI PC on the same Wi-Fi. The PC handles inference; the iPad is the interface.")
                }

                Section("Performance") {
                    if let s = appState.inferenceStats {
                        LabeledContent("Last tok/s", value: String(format: "%.1f", s.tokensPerSecond))
                        LabeledContent("Last TTFT", value: String(format: "%.2fs", s.timeToFirstToken))
                        LabeledContent("Last tokens", value: "\(s.totalTokens)")
                        LabeledContent("Memory", value: String(format: "%.1f MB", s.memoryResidentMB))
                    } else {
                        Text("Run a generation to see live stats.")
                            .foregroundStyle(NethTheme.textSecondary)
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Neth-AI")
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Engine", value: "llama.cpp")
                    LabeledContent("Platforms", value: "iPadOS / iOS 17+")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                localAPIEnabled = appState.localAPIEnabled
                pcServerHost = appState.pcServerHost
                pcServerPort = "\(appState.pcServerPort)"
            }
        }
    }
}

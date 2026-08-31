import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - AssistantView
// The first screen. AI-appliance feel: large Neth Orb centered, voice + text input,
// current model chip, generation state, stop button. Empty state with import CTA
// when no model is loaded.

struct AssistantView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var images = ImageInputManager()

    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool
    @State private var showImagePicker = false
    @State private var showFilePicker = false
    @State private var showModelSwitcher = false
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                NethBackground()

                VStack(spacing: 0) {
                    topBar
                    if let err = appState.lastError, appState.engineState == .error {
                        errorBanner(err)
                    }
                    if appState.currentModel == nil {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        orbAndResponse
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    inputBar
                }
                .padding(.horizontal, geo.size.width > 700 ? 60 : 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await ensureModelReady() }
        }
        .onChange(of: speech.transcript) { _, new in
            if speech.isListening { inputText = new }
        }
        .onChange(of: images.attachedImages) { _, new in
            appState.attachedImages = new
        }
        .sheet(isPresented: $showImagePicker) {
            PhotosPickerBridge(pickedImageData: Binding(
                get: { nil },
                set: { data in
                    if let data { images.addImage(data) }
                    showImagePicker = false
                }
            ))
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await importModel(from: url) }
                }
            case .failure(let err):
                importError = String(describing: err)
            }
        }
        .sheet(isPresented: $showModelSwitcher) {
            ModelSwitcherSheet()
                .environment(appState)
        }
    }

    // MARK: Error banner
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(msg)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button {
                appState.lastError = nil
                appState.setEngineState(.idle)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
        }
        .foregroundStyle(NethTheme.errorGlow)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NethTheme.errorGlow.opacity(0.1))
        .overlay(Rectangle().fill(NethTheme.errorGlow.opacity(0.3)).frame(height: 0.5), alignment: .top)
        .padding(.horizontal, 0)
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showModelSwitcher = true
            } label: {
                modelChip
            }
            .buttonStyle(.plain)

            Spacer()

            if appState.isGenerating {
                Button {
                    Task { await stopGeneration() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Stop")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(NethTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NethTheme.errorGlow.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(NethTheme.errorGlow.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            if let stats = appState.inferenceStats {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text(stats.formattedSummary)
                        .font(NethTheme.monoFont)
                }
                .foregroundStyle(NethTheme.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NethTheme.charcoal, in: Capsule())
                .overlay(Capsule().stroke(NethTheme.hairline, lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.isGenerating)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.inferenceStats != nil)
    }

    private var modelChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NethTheme.orange)
                .frame(width: 8, height: 8)
                .shadow(color: NethTheme.orange.opacity(0.9), radius: 5)
            Text(appState.currentModel?.displayName ?? "No model")
                .font(.caption.bold())
                .foregroundStyle(NethTheme.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NethTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(NethTheme.charcoal, in: Capsule())
        .overlay(Capsule().stroke(NethTheme.hairlineWarm.opacity(0.7), lineWidth: 1))
    }

    // MARK: Empty state (no model loaded)
    private var emptyState: some View {
        VStack(spacing: 36) {
            Spacer()

            NethOrbView(state: appState.engineState, size: 240)

            VStack(spacing: 12) {
                Text("Welcome to Neth-AI")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(NethTheme.textPrimary)
                Text("A local AI appliance. Import a GGUF model\nto bring it to life.")
                    .font(.body)
                    .foregroundStyle(NethTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 10) {
                        if importing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text(importing ? "Importing…" : "Import GGUF Model")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [NethTheme.orangeBright, NethTheme.orange, NethTheme.orangeDeep],
                            startPoint: .top, endPoint: .bottom
                        ),
                        in: Capsule()
                    )
                    .shadow(color: NethTheme.orange.opacity(0.5), radius: 18, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(importing)

                Text("Files app · AirDrop · iCloud Drive")
                    .font(.caption)
                    .foregroundStyle(NethTheme.textTertiary)
            }

            if let err = importError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(NethTheme.errorGlow)
                    .padding(.horizontal, 16)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Orb + response (when model loaded)
    private var orbAndResponse: some View {
        VStack(spacing: 16) {
            // Orb
            VStack(spacing: 8) {
                NethOrbView(state: appState.engineState, size: orbSize)
                    .padding(.top, 4)

                Text(appState.engineState.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(stateColor)
                    .textCase(.uppercase)
                    .tracking(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(stateColor.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(stateColor.opacity(0.3), lineWidth: 1))
                    .animation(.easeInOut(duration: 0.3), value: appState.engineState)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)

            // Response area
            responseArea
                .frame(maxHeight: .infinity)
        }
    }

    private var orbSize: CGFloat {
        // Smaller orb when there's a streaming response, larger when idle
        return appState.streamingResponse.isEmpty && !appState.isGenerating ? 220 : 140
    }

    private var stateColor: Color {
        switch appState.engineState {
        case .idle:        return NethTheme.textTertiary
        case .listening:   return NethTheme.amber
        case .thinking:    return NethTheme.orangeBright
        case .generating:  return NethTheme.orange
        case .complete:    return NethTheme.ember
        case .error:       return NethTheme.errorGlow
        }
    }

    private var responseArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if appState.streamingResponse.isEmpty && !appState.isGenerating {
                        promptHints
                    } else {
                        responseCard
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: appState.streamingResponse) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: appState.isGenerating) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var promptHints: some View {
        VStack(spacing: 14) {
            Text("Speak or type to begin.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(NethTheme.textPrimary)
            Text("Neth-AI runs entirely on this device.")
                .font(.subheadline)
                .foregroundStyle(NethTheme.textTertiary)
        }
        .padding(.top, 24)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundStyle(NethTheme.orange)
                Text(appState.currentModel?.displayName ?? "Neth-AI")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NethTheme.textSecondary)
                Spacer()
                if appState.isGenerating {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(NethTheme.orange)
                            .frame(width: 6, height: 6)
                            .opacity(0.6)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text("streaming")
                            .font(.caption2)
                            .foregroundStyle(NethTheme.orange)
                    }
                }
            }
            Text(appState.streamingResponse.isEmpty ? "…" : appState.streamingResponse)
                .font(.body)
                .foregroundStyle(NethTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [NethTheme.charcoal.opacity(0.9), NethTheme.panelDark.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NethTheme.hairlineWarm.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: NethTheme.orange.opacity(0.1), radius: 22, y: 8)
        .id("bottom")
    }

    // MARK: Input
    private var inputBar: some View {
        VStack(spacing: 10) {
            // attached images
            if !images.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.attachedImages) { img in
                            ZStack(alignment: .topTrailing) {
                                if let thumb = img.thumbnail, let uiImg = UIImage(data: thumb) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NethTheme.hairlineWarm, lineWidth: 1))
                                }
                                Button {
                                    images.removeImage(img.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white, .black.opacity(0.7))
                                }
                                .padding(2)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Mic
                Button {
                    Task { await toggleMic() }
                } label: {
                    Image(systemName: speech.isListening ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(speech.isListening ? NethTheme.orangeBright : NethTheme.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(NethTheme.charcoal)
                                .overlay(Circle().stroke(speech.isListening ? NethTheme.orange.opacity(0.7) : NethTheme.hairline, lineWidth: 1))
                        )
                        .shadow(color: speech.isListening ? NethTheme.orange.opacity(0.5) : .clear, radius: 12)
                        .scaleEffect(speech.isListening ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speech.isListening)
                }
                .buttonStyle(.plain)

                // Image attach
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NethTheme.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(NethTheme.charcoal).overlay(Circle().stroke(NethTheme.hairline, lineWidth: 1)))
                }
                .buttonStyle(.plain)

                // Text field
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Ask Neth…", text: $inputText, axis: .vertical)
                        .focused($inputFocused)
                        .font(.body)
                        .foregroundStyle(NethTheme.textPrimary)
                        .lineLimit(1...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(canSend ? NethTheme.orange : NethTheme.charcoalRaised)
                            )
                            .shadow(color: canSend ? NethTheme.orange.opacity(0.7) : .clear, radius: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.trailing, 4)
                    .padding(.bottom, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(NethTheme.charcoal)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(inputFocused ? NethTheme.orange.opacity(0.5) : NethTheme.hairline, lineWidth: 1)
                        )
                )
                .shadow(color: inputFocused ? NethTheme.orange.opacity(0.15) : .clear, radius: 12)
            }
            .padding(.vertical, 6)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: images.attachedImages.count)
    }

    private var canSend: Bool {
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.attachedImages.isEmpty)
            && appState.currentModel != nil
            && !appState.isGenerating
    }

    // MARK: Actions

    private func ensureModelReady() async {
        if appState.currentModel == nil {
            await appState.refreshInstalledModels()
        }
        guard let model = appState.currentModel else { return }
        if !appState.llmEngine.isLoaded {
            do {
                try await appState.llmEngine.loadModel(at: appState.modelManager.path(for: model), gpuLayers: 99)
                appState.isModelLoaded = true
            } catch {
                appState.lastError = String(describing: error)
                appState.setEngineState(.error)
            }
        }
    }

    private func importModel(from url: URL) async {
        importing = true
        defer { importing = false }
        do {
            let model = try await appState.modelManager.importModel(from: url, replace: true)
            await appState.refreshInstalledModels()
            try await appState.llmEngine.loadModel(at: appState.modelManager.path(for: model), gpuLayers: 99)
            appState.currentModel = model
            appState.isModelLoaded = true
            importError = nil
        } catch {
            importError = String(describing: error)
            appState.setEngineState(.error)
        }
    }

    private func toggleMic() async {
        if speech.isListening {
            speech.stopListening()
        } else {
            await speech.startListening()
        }
    }

    private func send() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || !images.attachedImages.isEmpty,
              let model = appState.currentModel else { return }

        inputText = ""
        inputFocused = false
        appState.streamingResponse = ""
        appState.isGenerating = true
        appState.setEngineState(.thinking)
        appState.inferenceStats = nil

        // Build conversation history + prompt
        var convo = appState.currentConversation ?? createConversation()
        let history = convo.messages
        let userMsg = ChatMessage(role: .user, content: prompt, images: images.attachedImages.map { $0.imageData })
        convo.messages.append(userMsg)
        appState.currentConversation = convo

        let promptForEngine = buildPrompt(history: history, user: prompt, model: model)

        do {
            let stream = appState.llmEngine.generate(prompt: promptForEngine, params: NethSamplingParams())
            appState.setEngineState(.generating)
            for try await token in stream {
                if !token.text.isEmpty {
                    appState.streamingResponse += token.text
                }
                if token.isFinal, let stats = token.stats {
                    appState.inferenceStats = stats
                }
            }
            appState.setEngineState(.complete)
            // persist
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: appState.streamingResponse,
                timestamp: Date(),
                stats: appState.inferenceStats,
                modelName: model.fileName
            )
            convo.messages.append(assistantMsg)
            convo.updatedAt = Date()
            try? ConversationStore.shared.save(convo)
            images.clear()
            appState.attachedImages = []
            // Auto-return to idle after a moment
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                if appState.engineState == .complete { appState.setEngineState(.idle) }
            }
        } catch {
            appState.lastError = String(describing: error)
            appState.setEngineState(.error)
        }

        appState.isGenerating = false
    }

    private func stopGeneration() async {
        await appState.llmEngine.cancel()
        appState.isGenerating = false
        appState.setEngineState(.complete)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            if appState.engineState == .complete { appState.setEngineState(.idle) }
        }
    }

    private func createConversation() -> Conversation {
        var c = Conversation(title: "Conversation \(appState.conversations.count + 1)")
        c.modelName = appState.currentModel?.fileName
        try? ConversationStore.shared.save(c)
        appState.conversations.insert(c, at: 0)
        return c
    }

    private func buildPrompt(history: [ChatMessage], user: String, model: InstalledModel) -> String {
        // Use ChatML template — works with Qwen2, Mistral, Phi-3, Gemma, Llama 3 (mostly)
        // For Llama 3 specifically we'd need <|start_header_id|> but ChatML is widely supported.
        var s = ""
        if history.isEmpty {
            s += "<|im_start|>system\nYou are Neth-AI, a helpful local assistant running entirely on-device. Be concise and direct. Answer in plain text without markdown headers.<|im_end|>\n"
        }
        for m in history.suffix(8) {
            switch m.role {
            case .user:      s += "<|im_start|>user\n\(m.content)<|im_end|>\n"
            case .assistant: s += "<|im_start|>assistant\n\(m.content)<|im_end|>\n"
            case .system:    s += "<|im_start|>system\n\(m.content)<|im_end|>\n"
            }
        }
        s += "<|im_start|>user\n\(user)<|im_end|>\n<|im_start|>assistant\n"
        return s
    }
}

// MARK: - Background

struct NethBackground: View {
    var body: some View {
        ZStack {
            NethTheme.voidBlack

            // Top orange ambient glow
            RadialGradient(
                colors: [NethTheme.orange.opacity(0.08), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            // Bottom subtle warmth
            RadialGradient(
                colors: [NethTheme.orangeDeep.opacity(0.04), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Fine noise/grain (subtle)
            LinearGradient(
                colors: [NethTheme.charcoal.opacity(0.3), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .opacity(0.3)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Model switcher sheet

struct ModelSwitcherSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var loading: InstalledModel?
    @State private var showFilePicker = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NethTheme.voidBlack.ignoresSafeArea()

                List {
                    Section {
                        if appState.installedModels.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "cube.transparent")
                                    .font(.system(size: 38))
                                    .foregroundStyle(NethTheme.orange)
                                    .shadow(color: NethTheme.orange.opacity(0.5), radius: 12)
                                Text("No models installed")
                                    .font(.headline)
                                    .foregroundStyle(NethTheme.textPrimary)
                                Text("Import a .gguf file to get started.")
                                    .font(.caption)
                                    .foregroundStyle(NethTheme.textSecondary)
                                Button {
                                    showFilePicker = true
                                } label: {
                                    Label("Import Model", systemImage: "square.and.arrow.down")
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(NethTheme.orange, in: Capsule())
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(appState.installedModels) { model in
                                Button {
                                    Task { await switchTo(model) }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(NethTheme.charcoalRaised)
                                                .frame(width: 38, height: 38)
                                            Image(systemName: model.supportsVision ? "eye.fill" : "cube.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(NethTheme.orange)
                                        }
                                        .overlay(
                                            Circle().stroke(
                                                appState.currentModel?.id == model.id ? NethTheme.orange.opacity(0.6) : .clear,
                                                lineWidth: 1.5
                                            )
                                        )

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(model.displayName)
                                                .font(.headline)
                                                .foregroundStyle(NethTheme.textPrimary)
                                            HStack(spacing: 6) {
                                                if let p = model.parameterCount {
                                                    Text(p)
                                                        .font(.caption2)
                                                        .foregroundStyle(NethTheme.textSecondary)
                                                }
                                                if let q = model.quantization {
                                                    Text("·")
                                                        .font(.caption2)
                                                        .foregroundStyle(NethTheme.textTertiary)
                                                    Text(q)
                                                        .font(.caption2)
                                                        .foregroundStyle(NethTheme.textSecondary)
                                                }
                                                Text("·")
                                                    .font(.caption2)
                                                    .foregroundStyle(NethTheme.textTertiary)
                                                Text(model.formattedSize)
                                                    .font(.caption2)
                                                    .foregroundStyle(NethTheme.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        if loading?.id == model.id {
                                            ProgressView()
                                        } else if appState.currentModel?.id == model.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(NethTheme.orange)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(NethTheme.charcoal.opacity(0.5))
                            }
                        }
                    } header: {
                        Text("Installed Models")
                            .textCase(.uppercase)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NethTheme.orange)
                    }

                    Section {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Import Another Model", systemImage: "plus.circle")
                                .foregroundStyle(NethTheme.orange)
                        }
                        .listRowBackground(NethTheme.charcoal.opacity(0.5))
                    }

                    if let err = importError {
                        Section {
                            Label(err, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(NethTheme.errorGlow)
                                .font(.caption)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Models")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(NethTheme.orange)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                _ = try await appState.modelManager.importModel(from: url, replace: false)
                                await appState.refreshInstalledModels()
                                importError = nil
                            } catch {
                                importError = String(describing: error)
                            }
                        }
                    }
                case .failure(let err):
                    importError = String(describing: err)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func switchTo(_ model: InstalledModel) async {
        loading = model
        defer { loading = nil }
        do {
            try await appState.llmEngine.loadModel(at: appState.modelManager.path(for: model), gpuLayers: 99)
            appState.currentModel = model
            appState.isModelLoaded = true
            dismiss()
        } catch {
            importError = String(describing: error)
            appState.setEngineState(.error)
        }
    }
}

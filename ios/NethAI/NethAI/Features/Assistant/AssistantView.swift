import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - AssistantView
// The first screen. AI-appliance feel: Neth Orb centered, voice + text input,
// current model, generation state, stop button. No settings dashboard.

struct AssistantView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var images = ImageInputManager()

    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool
    @State private var showImagePicker = false
    @State private var showFilePicker = false
    @State private var showModelSwitcher = false
    @State private var scrollTarget: UUID?

    var body: some View {
        ZStack {
            // Background ambience
            NethBackground()

            VStack(spacing: 0) {
                topBar
                orbSection
                responseSection
                inputBar
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
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
                    Task {
                        do {
                            let model = try await appState.modelManager.importModel(from: url, replace: true)
                            await appState.refreshInstalledModels()
                            try await appState.llmEngine.loadModel(at: appState.modelManager.path(for: model), gpuLayers: 99)
                            appState.currentModel = model
                            appState.isModelLoaded = true
                        } catch {
                            appState.lastError = String(describing: error)
                            appState.setEngineState(.error)
                        }
                    }
                }
            case .failure(let err):
                appState.lastError = String(describing: err)
                appState.setEngineState(.error)
            }
        }
        .sheet(isPresented: $showModelSwitcher) {
            ModelSwitcherSheet()
                .environment(appState)
        }
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(NethTheme.errorGlow.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(NethTheme.errorGlow.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if let stats = appState.inferenceStats {
                Text(stats.formattedSummary)
                    .font(NethTheme.monoFont)
                    .foregroundStyle(NethTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 6)
    }

    private var modelChip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NethTheme.orange)
                .frame(width: 8, height: 8)
                .shadow(color: NethTheme.orange.opacity(0.8), radius: 4)
            Text(appState.currentModel?.displayName ?? "No model")
                .font(.caption.bold())
                .foregroundStyle(NethTheme.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NethTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NethTheme.charcoal, in: Capsule())
        .overlay(Capsule().stroke(NethTheme.hairline, lineWidth: 1))
    }

    // MARK: Orb
    private var orbSection: some View {
        VStack(spacing: 8) {
            NethOrbView(state: appState.engineState, size: 220)
                .padding(.top, 12)

            Text(appState.engineState.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NethTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: Response
    private var responseSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if appState.streamingResponse.isEmpty && !appState.isGenerating {
                        emptyState
                    } else {
                        responseCard
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: appState.streamingResponse) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Speak or type to begin.")
                .font(NethTheme.titleFont)
                .foregroundStyle(NethTheme.textPrimary)
            Text("Neth-AI runs locally on this device.")
                .font(.subheadline)
                .foregroundStyle(NethTheme.textTertiary)
        }
        .padding(.top, 40)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundStyle(NethTheme.orange)
                Text(appState.currentModel?.displayName ?? "Neth-AI")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NethTheme.textSecondary)
                Spacer()
                if let stats = appState.inferenceStats {
                    Text(stats.formattedSummary)
                        .font(NethTheme.monoFont)
                        .foregroundStyle(NethTheme.textTertiary)
                }
            }
            Text(appState.streamingResponse.isEmpty ? "…" : appState.streamingResponse)
                .font(.body)
                .foregroundStyle(NethTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            NethTheme.charcoal
                .opacity(0.85)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NethTheme.hairlineWarm.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: NethTheme.orange.opacity(0.08), radius: 18, y: 6)
        .id("bottom")
    }

    // MARK: Input
    private var inputBar: some View {
        VStack(spacing: 8) {
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
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Button {
                                    images.removeImage(img.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .padding(2)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Mic
                Button {
                    Task { await toggleMic() }
                } label: {
                    Image(systemName: speech.isListening ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(speech.isListening ? NethTheme.orangeBright : NethTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(NethTheme.charcoal)
                                .overlay(Circle().stroke(speech.isListening ? NethTheme.orange.opacity(0.6) : NethTheme.hairline, lineWidth: 1))
                        )
                        .shadow(color: speech.isListening ? NethTheme.orange.opacity(0.4) : .clear, radius: 10)
                }
                .buttonStyle(.plain)

                // Image attach
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NethTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(NethTheme.charcoal).overlay(Circle().stroke(NethTheme.hairline, lineWidth: 1)))
                }
                .buttonStyle(.plain)

                // Text field
                TextField("Ask Neth…", text: $inputText, axis: .vertical)
                    .focused($inputFocused)
                    .font(.body)
                    .foregroundStyle(NethTheme.textPrimary)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(NethTheme.charcoal)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NethTheme.hairline, lineWidth: 1))
                    )

                // Send
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(canSend ? NethTheme.orange : NethTheme.charcoalRaised)
                        )
                        .shadow(color: canSend ? NethTheme.orange.opacity(0.6) : .clear, radius: 12)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.vertical, 8)
        }
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
    }

    private func createConversation() -> Conversation {
        var c = Conversation(title: "Conversation \(appState.conversations.count + 1)")
        c.modelName = appState.currentModel?.fileName
        try? ConversationStore.shared.save(c)
        appState.conversations.insert(c, at: 0)
        return c
    }

    private func buildPrompt(history: [ChatMessage], user: String, model: InstalledModel) -> String {
        // Simple chatml-style prompt that works reasonably with most instruction-tuned GGUF models.
        var s = ""
        if history.isEmpty {
            s += "<|im_start|>system\nYou are Neth-AI, a helpful local assistant running entirely on-device. Be concise and direct.<|im_end|>\n"
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
            RadialGradient(
                colors: [NethTheme.orange.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Model switcher sheet

struct ModelSwitcherSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var loading: InstalledModel?

    var body: some View {
        NavigationStack {
            List {
                Section("Installed") {
                    if appState.installedModels.isEmpty {
                        Text("No models installed. Use the Models tab to import.")
                            .foregroundStyle(NethTheme.textSecondary)
                    } else {
                        ForEach(appState.installedModels) { model in
                            Button {
                                Task { await switchTo(model) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.displayName)
                                            .foregroundStyle(NethTheme.textPrimary)
                                        Text(model.formattedSize)
                                            .font(.caption2)
                                            .foregroundStyle(NethTheme.textTertiary)
                                    }
                                    Spacer()
                                    if appState.currentModel?.id == model.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NethTheme.orange)
                                    }
                                    if loading?.id == model.id {
                                        ProgressView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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
            appState.lastError = String(describing: error)
            appState.setEngineState(.error)
        }
    }
}

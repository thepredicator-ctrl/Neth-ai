import SwiftUI
import Combine

@Observable
final class AppState {
    // Engine
    var engineState: OrbState = .idle
    var inferenceStats: InferenceStats?
    var currentModel: InstalledModel?
    var isModelLoaded: Bool = false
    var lastError: String?

    // Conversations
    var conversations: [Conversation] = []
    var currentConversation: Conversation?

    // Voice
    var isListening: Bool = false
    var transcript: String = ""

    // Vision
    var attachedImages: [AttachedImage] = []

    // Generation
    var streamingResponse: String = ""
    var isGenerating: Bool = false
    var pendingPrompt: String = ""

    // Model manager
    var installedModels: [InstalledModel] = []
    var modelManager: ModelManager = ModelManager.shared

    // Engine backend
    var llmEngine: LLMEngine

    // Local API
    var localAPIEnabled: Bool = false
    var localAPIPort: Int = 11434

    // PC Server connection (optional)
    var pcServerHost: String = ""
    var pcServerPort: Int = 11434
    var pcServerEnabled: Bool = false

    init() {
        self.llmEngine = LlamaEngine()
        Task { @MainActor in
            await self.refreshInstalledModels()
            await self.refreshConversations()
        }
    }

    @MainActor
    func refreshInstalledModels() async {
        installedModels = await modelManager.listInstalledModels()
        if currentModel == nil, let first = installedModels.first {
            currentModel = first
        }
    }

    @MainActor
    func refreshConversations() async {
        conversations = (try? ConversationStore.shared.loadAll()) ?? []
        conversations.sort { $0.updatedAt > $1.updatedAt }
        if currentConversation == nil, let first = conversations.first {
            currentConversation = first
        }
    }

    func setEngineState(_ state: OrbState) {
        engineState = state
        if state == .error {
            // brief error, then back to idle
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                if engineState == .error { engineState = .idle }
            }
        }
    }
}

struct AttachedImage: Identifiable, Sendable {
    let id = UUID()
    let imageData: Data
    let thumbnail: Data?
    var caption: String?
}

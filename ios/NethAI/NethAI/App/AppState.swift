import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // Engine
    @Published var engineState: OrbState = .idle
    @Published var inferenceStats: InferenceStats?
    @Published var currentModel: InstalledModel?
    @Published var isModelLoaded: Bool = false
    @Published var lastError: String?

    // Conversations
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?

    // Voice
    @Published var isListening: Bool = false
    @Published var transcript: String = ""

    // Vision
    @Published var attachedImages: [AttachedImage] = []

    // Generation
    @Published var streamingResponse: String = ""
    @Published var isGenerating: Bool = false
    @Published var pendingPrompt: String = ""

    // Model manager
    @Published var installedModels: [InstalledModel] = []
    let modelManager = ModelManager.shared

    // Engine backend
    let llmEngine: LLMEngine

    // Local API
    @Published var localAPIEnabled: Bool = false
    @Published var localAPIPort: Int = 11434

    // PC Server connection (optional)
    @Published var pcServerHost: String = ""
    @Published var pcServerPort: Int = 11434
    @Published var pcServerEnabled: Bool = false

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
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                if engineState == .error { engineState = .idle }
            }
        }
    }
}

struct AttachedImage: Identifiable, Sendable, Equatable {
    let id = UUID()
    let imageData: Data
    let thumbnail: Data?
    var caption: String?

    static func == (lhs: AttachedImage, rhs: AttachedImage) -> Bool {
        lhs.id == rhs.id
    }
}

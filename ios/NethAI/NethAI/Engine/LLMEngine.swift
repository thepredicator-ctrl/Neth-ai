import Foundation

// MARK: - Inference stats (real measured values, never fabricated)

struct InferenceStats: Sendable, Codable {
    let tokensPerSecond: Double
    let timeToFirstToken: Double      // seconds
    let totalTokens: Int
    let promptTokens: Int
    let generationDuration: Double    // seconds
    let contextSize: Int
    let memoryResidentMB: Double
    let metalAccelerated: Bool

    var formattedRate: String {
        String(format: "%.1f tok/s", tokensPerSecond)
    }
    var formattedTTFT: String {
        if timeToFirstToken < 1 {
            return String(format: "%.0fms TTFT", timeToFirstToken * 1000)
        } else {
            return String(format: "%.1fs TTFT", timeToFirstToken)
        }
    }
    var formattedSummary: String {
        "\(formattedRate) • \(formattedTTFT)"
    }
}

// MARK: - Chat message

struct ChatMessage: Identifiable, Sendable, Codable {
    let id: UUID
    var role: Role
    var content: String
    var images: [Data]
    var timestamp: Date
    var stats: InferenceStats?
    var modelName: String?

    enum Role: String, Codable, Sendable {
        case user, assistant, system
    }

    init(id: UUID = UUID(), role: Role, content: String, images: [Data] = [], timestamp: Date = Date(), stats: InferenceStats? = nil, modelName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = timestamp
        self.stats = stats
        self.modelName = modelName
    }
}

// MARK: - Sampling params

struct NethSamplingParams: Sendable {
    var temperature: Float = 0.7
    var topP: Float = 0.9
    var topK: Int = 40
    var maxTokens: Int = 1024
    var repeatPenalty: Float = 1.1
}

// MARK: - Engine protocol

protocol LLMEngine: AnyObject, Sendable {
    func loadModel(at path: URL, gpuLayers: Int) async throws
    func unloadModel() async
    var isLoaded: Bool { get }
    var loadedModelName: String? { get }
    var contextSize: Int { get }
    var metalAccelerated: Bool { get }

    func generate(prompt: String, params: NethSamplingParams) -> AsyncThrowingStream<EngineToken, Error>
    func cancel() async
}

struct EngineToken: Sendable {
    let text: String
    let isFinal: Bool
    let stats: InferenceStats?
}

enum LLMError: LocalizedError {
    case noModelLoaded
    case modelNotFound(String)
    case loadFailed(String)
    case inferenceFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:      return "No model is loaded. Import a GGUF model first."
        case .modelNotFound(let p): return "Model not found at \(p)"
        case .loadFailed(let m):    return "Failed to load model: \(m)"
        case .inferenceFailed(let m): return "Inference failed: \(m)"
        case .cancelled:            return "Cancelled."
        }
    }
}

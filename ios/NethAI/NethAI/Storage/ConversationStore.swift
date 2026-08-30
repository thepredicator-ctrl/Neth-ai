import Foundation

// MARK: - ConversationStore
// Persists conversations to JSON files in the app's Application Support directory.

final class ConversationStore: @unchecked Sendable {
    static let shared = ConversationStore()

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "ai.neth.NethAI.conversationstore")

    private var rootURL: URL {
        let base = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Conversations", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    func loadAll() throws -> [Conversation] {
        let urls = (try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
        var convos: [Conversation] = []
        for url in urls where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let convo = try? decoder.decode(Conversation.self, from: data) {
                convos.append(convo)
            }
        }
        return convos
    }

    func save(_ conversation: Conversation) throws {
        let url = rootURL.appendingPathComponent("\(conversation.id.uuidString).json")
        let data = try encoder.encode(conversation)
        try data.write(to: url, options: .atomic)
    }

    func delete(_ conversation: Conversation) throws {
        let url = rootURL.appendingPathComponent("\(conversation.id.uuidString).json")
        try? fm.removeItem(at: url)
    }

    func rename(_ conversation: Conversation, to name: String) throws {
        var c = conversation
        c.title = name
        try save(c)
    }
}

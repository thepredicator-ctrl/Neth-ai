import Foundation

struct Conversation: Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    var modelName: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Conversation", messages: [ChatMessage] = [], modelName: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelName = modelName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

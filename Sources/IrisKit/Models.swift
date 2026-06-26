import Foundation

public struct Message: Codable, Equatable {
    public let id: String
    public let role: String   // "user" | "assistant"
    public let text: String

    public init(id: String, role: String, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct Conversation: Codable, Equatable {
    public let id: String
    public var messages: [Message]

    public init(id: String, messages: [Message] = []) {
        self.id = id
        self.messages = messages
    }
}

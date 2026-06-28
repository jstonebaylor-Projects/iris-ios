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

/// A proactive message from an HQ agent (Intel Manager, Sensei, …), shown in
/// the app's Updates inbox. `url`, when non-empty, is an external link to open.
public struct AgentMessage: Codable, Equatable, Identifiable {
    public let ts: String
    public let source: String
    public let title: String
    public let body: String
    public let url: String

    public var id: String { ts + "|" + source }

    public init(ts: String, source: String, title: String, body: String, url: String) {
        self.ts = ts
        self.source = source
        self.title = title
        self.body = body
        self.url = url
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

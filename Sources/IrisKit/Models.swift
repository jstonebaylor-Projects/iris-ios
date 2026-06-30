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

/// An in-app action button on an agent message — the app POSTs `body` to `url`
/// when tapped (e.g. a Postmaster draft's Approve/Reject).
public struct AgentAction: Codable, Equatable, Identifiable {
    public let label: String
    public let url: String
    public let method: String
    public let body: [String: String]
    /// "resolve" (default) hides the message on success (Approve/Reject);
    /// "rate" records a 👍/👎 without resolving the card.
    public let kind: String

    public var id: String { label + "|" + url }

    public init(label: String, url: String, method: String = "POST", body: [String: String] = [:], kind: String = "resolve") {
        self.label = label
        self.url = url
        self.method = method
        self.body = body
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey { case label, url, method, body, kind }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        url = try c.decode(String.self, forKey: .url)
        method = try c.decodeIfPresent(String.self, forKey: .method) ?? "POST"
        body = try c.decodeIfPresent([String: String].self, forKey: .body) ?? [:]
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "resolve"
    }
}

/// A proactive message from an HQ agent (Intel Manager, Sensei, Postmaster, …),
/// shown in the app's Updates inbox. `url`, when non-empty, is an external link
/// to open; `actions`, when present, are in-app Approve/Reject-style buttons.
public struct AgentMessage: Codable, Equatable, Identifiable {
    public let ts: String
    public let source: String
    public let title: String
    public let body: String
    public let url: String
    public let actions: [AgentAction]

    public var id: String { ts + "|" + source }

    public init(ts: String, source: String, title: String, body: String, url: String, actions: [AgentAction] = []) {
        self.ts = ts
        self.source = source
        self.title = title
        self.body = body
        self.url = url
        self.actions = actions
    }

    enum CodingKeys: String, CodingKey { case ts, source, title, body, url, actions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ts = try c.decode(String.self, forKey: .ts)
        source = try c.decode(String.self, forKey: .source)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        url = try c.decode(String.self, forKey: .url)
        actions = try c.decodeIfPresent([AgentAction].self, forKey: .actions) ?? []
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

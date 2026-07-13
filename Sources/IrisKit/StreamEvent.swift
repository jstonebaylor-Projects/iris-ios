import Foundation

/// A write-capable tool's pending approval request (door unlock, send email, …).
public struct ApprovalInfo: Codable, Equatable, Identifiable {
    public let id: String        // server's request_id
    public let toolName: String
    public let intent: String
    public let summary: String

    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case toolName = "tool_name"
        case intent
        case summary
    }

    public init(id: String, toolName: String, intent: String, summary: String) {
        self.id = id
        self.toolName = toolName
        self.intent = intent
        self.summary = summary
    }
}

/// Events streamed from `/v1/voice/stream` as NDJSON.
public enum StreamEvent: Equatable {
    /// A text delta fragment.
    case text(delta: String)
    /// An audio chunk (base64-encoded).
    case audio(seq: Int, b64: String, format: String)
    /// Boundary marking the start of a new self-contained audio segment
    /// (a fresh mp3 — the player must reset its parser here, but keep playing).
    case audioSegment
    /// A write-capable tool needs Jeff's approval before it runs.
    case approval(ApprovalInfo)
    /// 2+ write-capable tools were proposed in one turn — one card, approve/decline all.
    /// Fires alongside `.approval` whenever there's at least one proposal (length 1+);
    /// a single-proposal turn's batch has exactly one item.
    case approvalBatch([ApprovalInfo])
    /// Stream complete.
    case done(conversationID: String)
    /// Server-side error.
    case error(code: String)
    /// An event type this client doesn't recognize.
    case unknown(type: String)
}

extension StreamEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case delta
        case seq
        case b64
        case format
        case conversationID = "conversation_id"
        case code
        case approval
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text":
            let delta = try container.decode(String.self, forKey: .delta)
            self = .text(delta: delta)
        case "audio":
            let seq    = try container.decode(Int.self,    forKey: .seq)
            let b64    = try container.decode(String.self, forKey: .b64)
            let format = try container.decode(String.self, forKey: .format)
            self = .audio(seq: seq, b64: b64, format: format)
        case "audio_segment":
            self = .audioSegment
        case "approval":
            self = .approval(try container.decode(ApprovalInfo.self, forKey: .approval))
        case "approval_batch":
            self = .approvalBatch(try container.decode([ApprovalInfo].self, forKey: .items))
        case "done":
            let cid = try container.decode(String.self, forKey: .conversationID)
            self = .done(conversationID: cid)
        case "error":
            let code = try container.decode(String.self, forKey: .code)
            self = .error(code: code)
        default:
            self = .unknown(type: type_)
        }
    }
}

import Foundation

/// Pure state reducer that maps StreamEvents onto conversation state.
///
/// Usage:
///   1. Call `send(userMessage:)` to begin a new user turn.
///   2. Feed each received StreamEvent to `apply(_:)`.
///   3. Read `conversation` for committed state, `inFlightAssistantText` for
///      the growing assistant response, and `lastError` for a failed turn.
///
/// The store is a value type (`struct`) with `mutating func` reducers,
/// making it straightforward to test with deterministic snapshots.
public struct ConversationStore {
    private var conversationID: String
    private var messages: [Message]
    private var inFlightText: String = ""
    private var inFlight: Bool = false

    /// The error code from the most recent failed turn, or nil if the last
    /// turn completed successfully (or no turn has failed yet).
    public private(set) var lastError: String?

    public init(conversationID: String = "") {
        self.conversationID = conversationID
        self.messages = []
    }

    /// Rehydrate a store from a previously persisted conversation, restoring
    /// both the committed messages and the conversation id (so the next turn
    /// continues the same server-side conversation).
    public init(conversation: Conversation) {
        self.conversationID = conversation.id
        self.messages = conversation.messages
    }

    // MARK: - Read

    /// The committed conversation snapshot.
    /// Does not include the in-flight assistant text — read `inFlightAssistantText` for that.
    public var conversation: Conversation {
        Conversation(id: conversationID, messages: messages)
    }

    /// The assistant text accumulated so far in the current in-flight turn.
    public var inFlightAssistantText: String { inFlightText }

    // MARK: - Write

    /// Begin a new user turn. Appends the user message and opens an in-flight window.
    /// Clears `lastError`.
    public mutating func send(userMessage: String, attachments: [AttachmentRef] = []) {
        messages.append(Message(id: UUID().uuidString, role: "user", text: userMessage, attachments: attachments))
        inFlightText = ""
        inFlight = true
        lastError = nil
    }

    /// Apply a stream event to the current state.
    ///
    /// - `.text(delta)` appends to the in-flight assistant text.
    /// - `.done(conversationID)` finalizes the assistant message and records the conversation id.
    /// - `.error(code)` marks the turn failed (sets `lastError`, discards partial assistant text)
    ///   without corrupting prior committed messages.
    /// - `.audio` and `.unknown` events are ignored by the reducer.
    public mutating func apply(_ event: StreamEvent) {
        switch event {
        case .text(let delta):
            guard inFlight else { return }
            inFlightText += delta

        case .done(let cid):
            guard inFlight else { return }
            messages.append(Message(id: UUID().uuidString, role: "assistant", text: inFlightText))
            conversationID = cid
            inFlightText = ""
            inFlight = false

        case .error(let code):
            lastError = code
            inFlightText = ""
            inFlight = false
            // The partial assistant message is discarded; prior messages are intact.

        case .audio, .audioSegment, .approval, .approvalBatch, .unknown:
            break
        }
    }
}

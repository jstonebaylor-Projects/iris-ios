import Foundation
import Testing
@testable import IrisKit

@Suite struct ConversationStoreTests {

    @Test func happyPathTurnBuildsConversation() {
        var store = ConversationStore()
        store.send(userMessage: "hi")
        store.apply(.text(delta: "Hel"))
        store.apply(.text(delta: "lo"))
        store.apply(.done(conversationID: "conv_1"))

        let conv = store.conversation
        #expect(conv.messages.count == 2)
        #expect(conv.messages[0].role == "user")
        #expect(conv.messages[0].text == "hi")
        #expect(conv.messages[1].role == "assistant")
        #expect(conv.messages[1].text == "Hello")
        #expect(conv.id == "conv_1")
    }

    @Test func errorMidTurnPreservesUserMessageAndPriorMessages() {
        var store = ConversationStore()
        store.send(userMessage: "hi")
        store.apply(.text(delta: "par"))
        store.apply(.error(code: "llm_error"))

        #expect(store.lastError == "llm_error")
        let conv = store.conversation
        #expect(conv.messages.count == 1) // user message only — no failed assistant message
        #expect(conv.messages[0].text == "hi")
    }

    @Test func secondTurnAppendsCorrectlyAndReusesConversationID() {
        var store = ConversationStore()

        store.send(userMessage: "hi")
        store.apply(.text(delta: "Hello"))
        store.apply(.done(conversationID: "conv_1"))

        store.send(userMessage: "bye")
        store.apply(.text(delta: "Goodbye"))
        store.apply(.done(conversationID: "conv_1"))

        let conv = store.conversation
        #expect(conv.messages.count == 4)
        #expect(conv.id == "conv_1")
        #expect(conv.messages[2].role == "user")
        #expect(conv.messages[2].text == "bye")
        #expect(conv.messages[3].role == "assistant")
        #expect(conv.messages[3].text == "Goodbye")
    }

    @Test func inFlightTextReflectsAccumulatedDeltas() {
        var store = ConversationStore()
        store.send(userMessage: "test")
        store.apply(.text(delta: "one "))
        store.apply(.text(delta: "two"))
        #expect(store.inFlightAssistantText == "one two")
    }

    @Test func inFlightTextClearedAfterDone() {
        var store = ConversationStore()
        store.send(userMessage: "test")
        store.apply(.text(delta: "response"))
        store.apply(.done(conversationID: "c1"))
        #expect(store.inFlightAssistantText == "")
        #expect(store.lastError == nil)
    }

    @Test func inFlightTextClearedAfterError() {
        var store = ConversationStore()
        store.send(userMessage: "test")
        store.apply(.text(delta: "partial"))
        store.apply(.error(code: "timeout"))
        #expect(store.inFlightAssistantText == "")
        #expect(store.lastError == "timeout")
    }

    @Test func lastErrorClearedOnNewTurn() {
        var store = ConversationStore()
        store.send(userMessage: "first")
        store.apply(.error(code: "oops"))
        #expect(store.lastError == "oops")

        store.send(userMessage: "retry")
        #expect(store.lastError == nil)
    }
}

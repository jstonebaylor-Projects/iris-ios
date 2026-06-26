import Foundation
import Testing
@testable import IrisKit

// MARK: - Canned LineSource for tests

private struct MockLineSource: LineSource {
    let rawLines: [String]

    func lines() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for line in rawLines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}

// MARK: - Tests

@Suite struct VoiceStreamConsumerTests {
    let consumer = VoiceStreamConsumer()

    // JSON fixtures
    let textJSON  = #"{"type":"text","delta":"Hi"}"#
    let audioJSON = #"{"type":"audio","seq":0,"b64":"AAAA","format":"mp3"}"#
    let doneJSON  = #"{"type":"done","conversation_id":"c1"}"#
    let errorJSON = #"{"type":"error","code":"timeout"}"#

    @Test func happyPathYieldsEventsInOrderAndFinishes() async throws {
        let source = MockLineSource(rawLines: [textJSON, "", audioJSON, doneJSON])
        var events: [StreamEvent] = []
        for try await event in consumer.consume(source) {
            events.append(event)
        }
        #expect(events.count == 3)
        #expect(events[0] == .text(delta: "Hi"))
        #expect(events[1] == .audio(seq: 0, b64: "AAAA", format: "mp3"))
        #expect(events[2] == .done(conversationID: "c1"))
    }

    @Test func errorEventYieldedAndStreamFinishes() async throws {
        let source = MockLineSource(rawLines: [errorJSON])
        var events: [StreamEvent] = []
        for try await event in consumer.consume(source) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0] == .error(code: "timeout"))
    }

    @Test func blankLinesAreSkipped() async throws {
        let source = MockLineSource(rawLines: ["", "   ", doneJSON])
        var events: [StreamEvent] = []
        for try await event in consumer.consume(source) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0] == .done(conversationID: "c1"))
    }

    @Test func doneStopsConsumingFurtherLines() async throws {
        // Lines after .done should not be yielded.
        let source = MockLineSource(rawLines: [doneJSON, textJSON])
        var events: [StreamEvent] = []
        for try await event in consumer.consume(source) {
            events.append(event)
        }
        #expect(events.count == 1)
        #expect(events[0] == .done(conversationID: "c1"))
    }
}

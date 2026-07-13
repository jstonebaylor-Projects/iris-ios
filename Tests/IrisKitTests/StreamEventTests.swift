import Foundation
import Testing
@testable import IrisKit

@Suite struct StreamEventTests {
    let decoder = JSONDecoder()

    @Test func decodeTextEvent() throws {
        let json = #"{"type":"text","delta":"Hello"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .text(delta: "Hello"))
    }

    @Test func decodeAudioEvent() throws {
        let json = #"{"type":"audio","seq":0,"b64":"AAAA","format":"mp3"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .audio(seq: 0, b64: "AAAA", format: "mp3"))
    }

    @Test func decodeAudioSegmentEvent() throws {
        let json = #"{"type":"audio_segment"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .audioSegment)
    }

    @Test func decodeApprovalEvent() throws {
        let json = #"{"type":"approval","approval":{"request_id":"appr_1","tool_name":"unlock_door","intent":"Unlock the front door","summary":"Schlage front door"}}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .approval(ApprovalInfo(id: "appr_1", toolName: "unlock_door", intent: "Unlock the front door", summary: "Schlage front door")))
    }

    @Test func decodeDoneEvent() throws {
        let json = #"{"type":"done","conversation_id":"conv-42"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .done(conversationID: "conv-42"))
    }

    @Test func decodeErrorEvent() throws {
        let json = #"{"type":"error","code":"rate_limited"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .error(code: "rate_limited"))
    }

    @Test func unknownTypeDecodesToUnknownCase() throws {
        let json = #"{"type":"ping"}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .unknown(type: "ping"))
    }

    @Test func decodeApprovalBatchEvent() throws {
        let json = #"{"type":"approval_batch","items":[{"request_id":"appr_1","tool_name":"create_event","intent":"Create calendar event","summary":"Team sync, 3pm"},{"request_id":"appr_2","tool_name":"create_event","intent":"Create calendar event","summary":"Dentist, 5pm"}]}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .approvalBatch([
            ApprovalInfo(id: "appr_1", toolName: "create_event", intent: "Create calendar event", summary: "Team sync, 3pm"),
            ApprovalInfo(id: "appr_2", toolName: "create_event", intent: "Create calendar event", summary: "Dentist, 5pm"),
        ]))
    }

    @Test func decodeApprovalEventStillWorksUnchanged() throws {
        // Regression: the existing singular event must keep decoding exactly as before.
        let json = #"{"type":"approval","approval":{"request_id":"appr_1","tool_name":"unlock_door","intent":"Unlock the front door","summary":"Schlage front door"}}"#.data(using: .utf8)!
        let event = try decoder.decode(StreamEvent.self, from: json)
        #expect(event == .approval(ApprovalInfo(id: "appr_1", toolName: "unlock_door", intent: "Unlock the front door", summary: "Schlage front door")))
    }
}

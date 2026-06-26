import Foundation
import Testing
@testable import IrisKit

@Suite struct NDJSONDecoderTests {

    @Test func decodeLinesSkipsBlanksAndPreservesOrder() {
        let lines = [
            #"{"type":"text","delta":"Hi"}"#,
            "",
            #"{"type":"audio","seq":1,"b64":"BBBB","format":"mp3"}"#,
            #"{"type":"done","conversation_id":"c1"}"#
        ]
        let events = NDJSONDecoder.decodeLines(lines)
        #expect(events.count == 3)
        #expect(events[0] == .text(delta: "Hi"))
        #expect(events[1] == .audio(seq: 1, b64: "BBBB", format: "mp3"))
        #expect(events[2] == .done(conversationID: "c1"))
    }

    @Test func decodeLinesSingleErrorEvent() {
        let lines = [#"{"type":"error","code":"timeout"}"#]
        let events = NDJSONDecoder.decodeLines(lines)
        #expect(events == [.error(code: "timeout")])
    }

    @Test func parseLineReturnsNilForBlank() throws {
        #expect(try NDJSONDecoder.parseLine("") == nil)
        #expect(try NDJSONDecoder.parseLine("   ") == nil)
    }

    @Test func parseLineParsesTextEvent() throws {
        let event = try NDJSONDecoder.parseLine(#"{"type":"text","delta":"world"}"#)
        #expect(event == .text(delta: "world"))
    }
}

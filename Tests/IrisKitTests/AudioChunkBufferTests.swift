import Foundation
import Testing
@testable import IrisKit

@Suite struct AudioChunkBufferTests {

    @Test func inOrderChunksReleasedImmediately() {
        var buffer = AudioChunkBuffer()
        let chunk0 = Data([1])
        let chunk1 = Data([2])
        let chunk2 = Data([3])

        let r0 = buffer.accept(seq: 0, b64: chunk0.base64EncodedString())
        let r1 = buffer.accept(seq: 1, b64: chunk1.base64EncodedString())
        let r2 = buffer.accept(seq: 2, b64: chunk2.base64EncodedString())

        #expect(r0 == [chunk0])
        #expect(r1 == [chunk1])
        #expect(r2 == [chunk2])
    }

    @Test func outOfOrderHoldsUntilGapFilled() {
        var buffer = AudioChunkBuffer()
        let chunk0 = Data([10])
        let chunk1 = Data([20])
        let chunk2 = Data([30])

        let r0 = buffer.accept(seq: 0, b64: chunk0.base64EncodedString())
        #expect(r0 == [chunk0])

        let r2 = buffer.accept(seq: 2, b64: chunk2.base64EncodedString())
        #expect(r2 == []) // gap at seq 1 — nothing past it releases

        let r1 = buffer.accept(seq: 1, b64: chunk1.base64EncodedString())
        #expect(r1 == [chunk1, chunk2]) // gap filled — both 1 and 2 released in order
    }

    @Test func decodedBytesMatchOriginal() {
        var buffer = AudioChunkBuffer()
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let released = buffer.accept(seq: 0, b64: original.base64EncodedString())
        #expect(released == [original])
    }

    @Test func invalidBase64IsSkipped() {
        var buffer = AudioChunkBuffer()
        let result = buffer.accept(seq: 0, b64: "!!!not-valid-base64!!!")
        #expect(result == [])
        // Seq 0 was not advanced (invalid chunk dropped), so a valid seq 0 still works.
        let chunk = Data([42])
        let r2 = buffer.accept(seq: 0, b64: chunk.base64EncodedString())
        #expect(r2 == [chunk])
    }

    @Test func flushReleasesTrailingBufferedChunks() {
        var buffer = AudioChunkBuffer()
        let chunk0 = Data([0])
        let chunk2 = Data([99])

        _ = buffer.accept(seq: 0, b64: chunk0.base64EncodedString()) // released immediately
        _ = buffer.accept(seq: 2, b64: chunk2.base64EncodedString()) // held — gap at seq 1

        let flushed = buffer.flush()
        #expect(flushed == [chunk2]) // trailing chunk released despite gap
    }

    @Test func flushReturnsEmptyWhenNothingBuffered() {
        var buffer = AudioChunkBuffer()
        _ = buffer.accept(seq: 0, b64: Data([1]).base64EncodedString())
        _ = buffer.accept(seq: 1, b64: Data([2]).base64EncodedString())
        #expect(buffer.flush() == [])
    }
}

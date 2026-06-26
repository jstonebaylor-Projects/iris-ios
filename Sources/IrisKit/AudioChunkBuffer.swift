import Foundation

/// Pure-logic buffer that accepts audio events and releases base64-decoded
/// Data chunks in correct `seq` order for gapless playback.
///
/// - In-order arrival: chunks are released immediately.
/// - Out-of-order arrival: chunks are held until the contiguous run from
///   the next expected seq can be released.
/// - Invalid base64: silently skipped (chunk is dropped, no crash).
/// - `flush()`: releases all remaining buffered chunks sorted by seq
///   (use at end-of-stream to drain any trailing out-of-order chunks).
public struct AudioChunkBuffer {
    private var nextSeq: Int = 0
    private var pending: [Int: Data] = [:]

    public init() {}

    /// Accept an audio chunk. Returns any now-releasable chunks in seq order.
    @discardableResult
    public mutating func accept(seq: Int, b64: String) -> [Data] {
        guard let data = Data(base64Encoded: b64) else { return [] }
        pending[seq] = data
        return drain()
    }

    /// Release all remaining buffered chunks sorted by seq.
    /// Resets the buffer. Call at end-of-stream.
    public mutating func flush() -> [Data] {
        let result = pending.keys.sorted().compactMap { pending[$0] }
        pending = [:]
        return result
    }

    // MARK: - Private

    /// Walk the pending map from nextSeq and release the contiguous run.
    private mutating func drain() -> [Data] {
        var result: [Data] = []
        while let data = pending[nextSeq] {
            result.append(data)
            pending.removeValue(forKey: nextSeq)
            nextSeq += 1
        }
        return result
    }
}

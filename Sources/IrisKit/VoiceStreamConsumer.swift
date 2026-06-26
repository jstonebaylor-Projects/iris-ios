import Foundation

// MARK: - LineSource protocol

/// An abstract source of NDJSON text lines.
/// Decouples VoiceStreamConsumer from URLSession for testability.
public protocol LineSource {
    func lines() -> AsyncThrowingStream<String, Error>
}

// MARK: - Consumer

public struct VoiceStreamConsumer {
    public init() {}

    /// Turn a LineSource into an AsyncThrowingStream of StreamEvents.
    ///
    /// - Blank lines are skipped.
    /// - Stops after a `.done` or `.error` event, or when the source ends.
    /// - `.error` events are yielded normally (not thrown) — they are terminal
    ///   per the stream contract.
    public func consume(_ source: any LineSource) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in source.lines() {
                        guard let event = try NDJSONDecoder.parseLine(line) else { continue }
                        continuation.yield(event)
                        switch event {
                        case .done, .error:
                            continuation.finish()
                            return
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - URLSession adapter

/// Thin adapter that wraps URLSession's async line sequence as a LineSource.
/// Not unit-tested against the network; the LineSource protocol is what tests use.
public struct URLSessionLineSource: LineSource {
    private let request: URLRequest
    private let session: URLSession

    public init(request: URLRequest, session: URLSession = .shared) {
        self.request = request
        self.session = session
    }

    public func lines() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, _) = try await session.bytes(for: request)
                    for try await line in asyncBytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

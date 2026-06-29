import Foundation

// MARK: - Transport abstraction

public protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// MARK: - URLSession conformance

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}

// MARK: - Response types

public struct TranscribeResponse: Codable {
    public let text: String
    public let language: String
}

public struct NotificationsResponse: Codable {
    public let messages: [AgentMessage]
}

// MARK: - Client

public struct IrisClient {
    public let baseURL: URL
    private let token: String
    public let transport: HTTPTransport

    public init(baseURL: URL, token: String, session: HTTPTransport = URLSession.shared) {
        self.baseURL = baseURL
        self.token = token
        self.transport = session
    }

    /// Only send an Authorization header when a token is set. An empty token
    /// would become "Bearer " which Iris's strict auth rejects as 401; omitting
    /// the header makes Iris treat the caller as the default local user.
    private func applyAuth(to req: inout URLRequest) {
        guard !token.isEmpty else { return }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - Request builders

    /// POST /v1/voice/stream  — NDJSON streaming endpoint.
    public func voiceStreamRequest(
        message: String,
        conversationID: String,
        voice: Bool
    ) -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/voice/stream")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "message": message,
            "conversation_id": conversationID,
            "voice": voice
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// POST /v1/transcribe?content_type=audio/mp4  — raw audio body, NOT multipart.
    public func transcribeRequest(audio: Data) -> URLRequest {
        var comps = URLComponents(url: baseURL.appendingPathComponent("v1/transcribe"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "content_type", value: "audio/mp4")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        applyAuth(to: &req)
        req.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        req.httpBody = audio
        return req
    }

    /// POST /v1/approvals/{id}  — record an approval decision
    /// ("approved" | "declined" | "cancelled").
    public func approvalDecisionRequest(id: String, decision: String) -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/approvals/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["decision": decision])
        return req
    }

    /// Record a decision on a pending approval. True if the server accepted it (HTTP 200).
    @discardableResult
    public func decideApproval(id: String, decision: String) async throws -> Bool {
        let (_, response) = try await transport.send(approvalDecisionRequest(id: id, decision: decision))
        return response.statusCode == 200
    }

    /// POST /v1/push/register  — device token registration.
    public func registerPushRequest(deviceToken: String) -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/push/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        applyAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_token": deviceToken,
            "platform": "ios"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    // MARK: - Performing requests

    /// Perform a transcription request and decode the response.
    public func transcribe(audio: Data) async throws -> TranscribeResponse {
        let req = transcribeRequest(audio: audio)
        let (data, _) = try await transport.send(req)
        return try JSONDecoder().decode(TranscribeResponse.self, from: data)
    }

    /// Perform an agent-message action button (e.g. Approve/Reject a Postmaster
    /// draft): POST its `body` to its absolute `url`. True on a 2xx response.
    @discardableResult
    public func performAction(_ action: AgentAction) async throws -> Bool {
        guard let url = URL(string: action.url) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = action.method.isEmpty ? "POST" : action.method
        applyAuth(to: &req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: action.body)
        let (_, response) = try await transport.send(req)
        return (200...299).contains(response.statusCode)
    }

    /// GET /v1/notifications — the agent messages for the in-app Updates inbox.
    public func notificationsRequest() -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/notifications")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        applyAuth(to: &req)
        return req
    }

    /// Fetch the recent agent messages (newest first).
    public func notifications() async throws -> [AgentMessage] {
        let (data, _) = try await transport.send(notificationsRequest())
        return try JSONDecoder().decode(NotificationsResponse.self, from: data).messages
    }
}

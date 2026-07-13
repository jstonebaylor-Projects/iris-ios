import Foundation
import Testing
@testable import IrisKit

// A simple mock transport that records the last request and returns a canned response.
final class MockTransport: HTTPTransport {
    var lastRequest: URLRequest?
    var responseData: Data = Data()
    var responseStatus: Int = 200

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let resp = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatus,
            httpVersion: nil,
            headerFields: nil)!
        return (responseData, resp)
    }
}

@Suite struct IrisClientTests {
    let mock: MockTransport
    let client: IrisClient

    init() {
        mock = MockTransport()
        client = IrisClient(
            baseURL: URL(string: "https://iris.example.com")!,
            token: "test-token",
            session: mock)
    }

    // MARK: - voiceStreamRequest

    @Test func voiceStreamRequestMethod() {
        let req = client.voiceStreamRequest(message: "hello", conversationID: "c1", voice: true)
        #expect(req.httpMethod == "POST")
    }

    @Test func voiceStreamRequestURL() {
        let req = client.voiceStreamRequest(message: "hello", conversationID: "c1", voice: false)
        #expect(req.url?.path == "/v1/voice/stream")
    }

    @Test func voiceStreamRequestAuthHeader() {
        let req = client.voiceStreamRequest(message: "hello", conversationID: "c1", voice: true)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test func voiceStreamRequestBodyFields() throws {
        let req = client.voiceStreamRequest(message: "sup", conversationID: "conv-99", voice: false)
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["message"] as? String == "sup")
        #expect(json["conversation_id"] as? String == "conv-99")
        #expect(json["voice"] as? Bool == false)
    }

    // MARK: - transcribeRequest

    @Test func transcribeRequestURL() {
        let req = client.transcribeRequest(audio: Data())
        #expect(req.url?.path == "/v1/transcribe")
        #expect(req.url?.query?.contains("content_type=audio") == true)
    }

    @Test func transcribeRequestBearer() {
        let req = client.transcribeRequest(audio: Data())
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test func transcribeRequestBodyIsRawAudio() {
        let audioBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let req = client.transcribeRequest(audio: audioBytes)
        #expect(req.httpBody == audioBytes)
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "audio/mp4")
    }

    // MARK: - notifications

    @Test func notificationsRequestURL() {
        let req = client.notificationsRequest()
        #expect(req.url?.path == "/v1/notifications")
        #expect(req.httpMethod == "GET")
    }

    @Test func notificationsDecodes() async throws {
        mock.responseData = #"{"messages":[{"ts":"t1","source":"sensei","title":"Sensei","body":"Train harder.","url":""},{"ts":"t2","source":"intel","title":"Intel Manager","body":"Update.","url":"https://x"}]}"#.data(using: .utf8)!
        let msgs = try await client.notifications()
        #expect(msgs.count == 2)
        #expect(msgs[0].source == "sensei")
        #expect(msgs[1].url == "https://x")
    }

    @Test func notificationsDecodeActions() async throws {
        mock.responseData = #"{"messages":[{"ts":"t1","source":"postmaster","title":"Draft ready","body":"Reply to x","url":"","actions":[{"label":"Approve & send","url":"http://k/postmaster/drafts/d1/decision","method":"POST","body":{"decision":"approve","thumbs":"up"}},{"label":"Reject","url":"http://k/postmaster/drafts/d1/decision","body":{"decision":"reject","thumbs":"down"}}]}]}"#.data(using: .utf8)!
        let msgs = try await client.notifications()
        #expect(msgs[0].actions.count == 2)
        #expect(msgs[0].actions[0].label == "Approve & send")
        #expect(msgs[0].actions[0].body["decision"] == "approve")
        #expect(msgs[0].actions[1].method == "POST")   // defaulted
    }

    // MARK: - approvalDecisionRequest

    @Test func approvalDecisionRequestBuilds() throws {
        let req = client.approvalDecisionRequest(id: "appr_1", decision: "approved")
        #expect(req.url?.path == "/v1/approvals/appr_1")
        #expect(req.httpMethod == "POST")
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["decision"] as? String == "approved")
    }

    // MARK: - registerPushRequest

    @Test func registerPushRequestURL() {
        let req = client.registerPushRequest(deviceToken: "abc123")
        #expect(req.url?.path == "/v1/push/register")
    }

    @Test func registerPushRequestBodyFields() throws {
        let req = client.registerPushRequest(deviceToken: "abc123")
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["device_token"] as? String == "abc123")
        #expect(json["platform"] as? String == "ios")
    }

    @Test func registerPushRequestBearer() {
        let req = client.registerPushRequest(deviceToken: "tok")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    // MARK: - voiceStreamRequest attachments

    @Test func voiceStreamRequestOmitsAttachmentsKeyWhenNoneGiven() throws {
        let req = client.voiceStreamRequest(message: "hi", conversationID: "c1", voice: false)
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["attachments"] == nil)
    }

    @Test func voiceStreamRequestIncludesAttachments() throws {
        let attachment = OutgoingAttachment(filename: "x.png", mimeType: "image/png", dataBase64: "QUJD")
        let req = client.voiceStreamRequest(message: "look", conversationID: "c1", voice: false, attachments: [attachment])
        let body = try #require(req.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let attachments = try #require(json["attachments"] as? [[String: Any]])
        #expect(attachments.count == 1)
        #expect(attachments[0]["filename"] as? String == "x.png")
        #expect(attachments[0]["mime_type"] as? String == "image/png")
        #expect(attachments[0]["data_base64"] as? String == "QUJD")
    }

    // MARK: - decideApprovals

    @Test func decideApprovalsCallsDecideOncePerID() async throws {
        mock.responseStatus = 200
        let results = try await client.decideApprovals(ids: ["appr_1", "appr_2"], decision: "approved")
        #expect(results == [true, true])
        // Last request recorded by the mock is for the last id in the batch.
        #expect(mock.lastRequest?.url?.path == "/v1/approvals/appr_2")
    }
}

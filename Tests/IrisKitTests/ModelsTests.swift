import Foundation
import Testing
@testable import IrisKit

@Suite struct ModelsTests {
    @Test func attachmentRefDecodesSnakeCaseKeys() throws {
        let json = #"{"id":"att_1","mime_type":"image/png","local_filename":"att_1.png"}"#.data(using: .utf8)!
        let ref = try JSONDecoder().decode(AttachmentRef.self, from: json)
        #expect(ref == AttachmentRef(id: "att_1", mimeType: "image/png", localFilename: "att_1.png"))
    }

    @Test func messageDecodesWithoutAttachmentsKey() throws {
        // Old persisted JSON, predates the attachments field.
        let json = #"{"id":"m1","role":"user","text":"hi"}"#.data(using: .utf8)!
        let message = try JSONDecoder().decode(Message.self, from: json)
        #expect(message.attachments == [])
    }

    @Test func messageDecodesWithAttachments() throws {
        let json = #"{"id":"m1","role":"user","text":"hi","attachments":[{"id":"att_1","mime_type":"image/png","local_filename":"att_1.png"}]}"#.data(using: .utf8)!
        let message = try JSONDecoder().decode(Message.self, from: json)
        #expect(message.attachments == [AttachmentRef(id: "att_1", mimeType: "image/png", localFilename: "att_1.png")])
    }

    @Test func messageRoundTripsAttachmentsThroughEncodeDecode() throws {
        let original = Message(id: "m1", role: "user", text: "hi",
                                attachments: [AttachmentRef(id: "att_1", mimeType: "image/png", localFilename: "att_1.png")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded == original)
    }
}

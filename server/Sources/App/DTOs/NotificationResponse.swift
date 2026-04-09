import Vapor

struct NotificationResponse: Content {
    let message: String
    let responseId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case responseId = "response_id"
    }

    static let sent = NotificationResponse(message: "Notification sent", responseId: nil)
}

import Vapor

struct NotificationResponse: Content {
    let message: String

    static let sent = NotificationResponse(message: "Notification sent")
}

import Foundation
import SwiftData

@Model
final class NotificationRecord {
    var title: String?
    var subtitle: String?
    var message: String?
    var threadId: String?
    var openURL: String?
    var requestIdentifier: String?
    @Attribute(.unique) var id: UUID
    var receivedAt: Date

    init(
        id: UUID = UUID(),
        requestIdentifier: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        message: String? = nil,
        threadId: String? = nil,
        openURL: String? = nil,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.requestIdentifier = requestIdentifier
        self.title = title
        self.subtitle = subtitle
        self.message = message
        self.threadId = threadId
        self.openURL = openURL
        self.receivedAt = receivedAt
    }

    var displayText: String {
        if let title, let message {
            return "\(title): \(message)"
        }
        return title ?? message ?? ""
    }
}

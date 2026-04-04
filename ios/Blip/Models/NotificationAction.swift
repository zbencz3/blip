import Foundation

struct NotificationAction: Codable, Sendable {
    let id: String
    let label: String
    let webhook: String?
    let destructive: Bool?
}

import Foundation

struct NotificationAction: Codable, Sendable {
    let id: String
    let label: String
    let webhook: String?
    let destructive: Bool?
    let responseChannel: Bool?
    let type: String?
    let textInputPlaceholder: String?

    enum CodingKeys: String, CodingKey {
        case id, label, webhook, destructive, type
        case responseChannel = "response_channel"
        case textInputPlaceholder = "text_input_placeholder"
    }
}

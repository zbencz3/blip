import Vapor

struct NotificationRequest: Content {
    var title: String?
    var subtitle: String?
    var message: String?
    var threadId: String?
    var sound: String?
    var openUrl: String?
    var imageUrl: String?
    var expirationDate: String?
    var filterCriteria: String?
    var interruptionLevel: String?
    var actions: [NotificationAction]?

    enum CodingKeys: String, CodingKey {
        case title, subtitle, message, sound, actions
        case threadId = "thread_id"
        case openUrl = "open_url"
        case imageUrl = "image_url"
        case expirationDate = "expiration_date"
        case filterCriteria = "filter_criteria"
        case interruptionLevel = "interruption_level"
    }

    func validate() throws {
        let hasTitle = title?.isEmpty == false
        let hasMessage = message?.isEmpty == false
        guard hasTitle || hasMessage else {
            throw Abort(.unprocessableEntity, reason: "Either 'title' or 'message' must be provided and non-empty.")
        }

        if let openUrl {
            guard openUrl.hasPrefix("https://") || openUrl.hasPrefix("http://") else {
                throw Abort(.unprocessableEntity, reason: "open_url must start with 'https://' or 'http://'.")
            }
        }

        if let actions {
            guard actions.count <= 4 else {
                throw Abort(.unprocessableEntity, reason: "Maximum 4 actions allowed.")
            }
            for action in actions {
                guard !action.id.isEmpty else {
                    throw Abort(.unprocessableEntity, reason: "Action 'id' must be non-empty.")
                }
                guard !action.label.isEmpty else {
                    throw Abort(.unprocessableEntity, reason: "Action 'label' must be non-empty.")
                }
                if let webhook = action.webhook {
                    guard webhook.hasPrefix("https://") else {
                        throw Abort(.unprocessableEntity, reason: "Action webhook URL must start with 'https://'.")
                    }
                }
            }
        }
    }
}

struct NotificationAction: Content, Sendable {
    let id: String
    let label: String
    let webhook: String?
    let destructive: Bool?
}

import Vapor

struct ResponseSubmission: Content {
    let actionID: String
    let text: String?
    let deviceName: String?

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case text
        case deviceName = "device_name"
    }
}

struct PollResponse: Content {
    let status: String
    let actionID: String?
    let text: String?
    let deviceName: String?
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case actionID = "action_id"
        case text
        case deviceName = "device_name"
        case respondedAt = "responded_at"
    }
}

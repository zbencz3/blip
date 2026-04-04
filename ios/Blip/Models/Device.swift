import Foundation

struct Device: Codable, Identifiable {
    let id: UUID
    let deviceToken: String
    let deviceName: String
    let deviceSecret: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceToken = "device_token"
        case deviceName = "device_name"
        case deviceSecret = "device_secret"
        case createdAt = "created_at"
    }

    var webhookURL: String? {
        guard let deviceSecret else { return nil }
        return "\(Constants.apiBaseURL)/\(deviceSecret)"
    }

    var curlCommand: String? {
        guard let webhookURL else { return nil }
        return "curl -X POST \(webhookURL) \\\n  -d 'Hello world! 🚀'"
    }
}

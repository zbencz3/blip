import Vapor

struct RotateSecretResponse: Content {
    let secret: String
    let webhookUrl: String

    enum CodingKeys: String, CodingKey {
        case secret
        case webhookUrl = "webhook_url"
    }
}

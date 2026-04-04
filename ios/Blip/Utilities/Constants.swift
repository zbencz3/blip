import Foundation

enum Constants {
    static let baseURL = "http://localhost:8080"
    static let apiBaseURL = "\(baseURL)/v1"

    enum Keychain {
        static let service = "com.isylva.blip"
        static let secretKey = "user_secret"
    }

    enum UserDefaultsKeys {
        static let retentionPeriod = "notification_retention_period"
        static let lastPushReceived = "last_push_received"
        static let lastWebhookUsed = "last_webhook_used"
    }

    static let trialEndDate = "Apr 8, 2026"
}

import Foundation

enum Constants {
    static let baseURL = "https://bzap-server.fly.dev"
    static let apiBaseURL = "\(baseURL)/v1"

    enum Keychain {
        static let service = "com.isylva.boopsy"
        static let secretKey = "user_secret"
    }

    enum UserDefaultsKeys {
        static let retentionPeriod = "notification_retention_period"
        static let lastPushReceived = "last_push_received"
        static let lastWebhookUsed = "last_webhook_used"
        static let firstLaunchDate = "first_launch_date"
    }

    static let trialDurationDays = 14
}

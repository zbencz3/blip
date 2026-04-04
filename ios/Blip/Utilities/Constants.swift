import Foundation

enum Constants {
    #if DEBUG
    static let baseURL = "http://192.168.1.145:8080"
    #else
    static let baseURL = "https://bzap-server.onrender.com"
    #endif
    static let apiBaseURL = "\(baseURL)/v1"

    enum Keychain {
        static let service = "com.isylva.boopsy"
        static let secretKey = "user_secret"
    }

    enum UserDefaultsKeys {
        static let retentionPeriod = "notification_retention_period"
        static let lastPushReceived = "last_push_received"
        static let lastWebhookUsed = "last_webhook_used"
    }

    static let trialEndDate = "Apr 8, 2026"
}

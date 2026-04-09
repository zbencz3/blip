import Fluent
import Vapor

final class Monitor: Model, Content, @unchecked Sendable {
    static let schema = "monitors"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "name") var name: String
    @Field(key: "url") var url: String
    @Field(key: "interval") var interval: Int
    @Field(key: "status") var status: String
    @OptionalField(key: "last_checked_at") var lastCheckedAt: Date?
    @OptionalField(key: "last_status_change") var lastStatusChange: Date?
    @Field(key: "consecutive_failures") var consecutiveFailures: Int
    @Field(key: "type") var type: String
    @OptionalField(key: "heartbeat_token") var heartbeatToken: String?
    @OptionalField(key: "grace_period") var gracePeriod: Int?
    @Field(key: "method") var method: String
    @OptionalField(key: "keyword") var keyword: String?
    @Field(key: "keyword_should_exist") var keywordShouldExist: Bool
    @Field(key: "failure_threshold") var failureThreshold: Int
    @OptionalField(key: "ssl_expires_at") var sslExpiresAt: Date?
    @Field(key: "ssl_alert_days") var sslAlertDays: Int
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        name: String,
        url: String,
        interval: Int,
        status: String = "pending",
        consecutiveFailures: Int = 0,
        type: String = "http",
        method: String = "HEAD",
        keyword: String? = nil,
        keywordShouldExist: Bool = true,
        failureThreshold: Int = 3,
        gracePeriod: Int? = nil,
        sslAlertDays: Int = 14
    ) {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.url = url
        self.interval = interval
        self.status = status
        self.consecutiveFailures = consecutiveFailures
        self.type = type
        self.method = method
        self.keyword = keyword
        self.keywordShouldExist = keywordShouldExist
        self.failureThreshold = failureThreshold
        self.gracePeriod = gracePeriod
        self.sslAlertDays = sslAlertDays
    }

    static func generateHeartbeatToken() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return "bps_hb_" + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

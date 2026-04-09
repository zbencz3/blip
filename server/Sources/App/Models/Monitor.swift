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
        consecutiveFailures: Int = 0
    ) {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.url = url
        self.interval = interval
        self.status = status
        self.consecutiveFailures = consecutiveFailures
    }
}

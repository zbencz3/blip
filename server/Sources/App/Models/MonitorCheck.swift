import Fluent
import Vapor

final class MonitorCheck: Model, Content, @unchecked Sendable {
    static let schema = "monitor_checks"

    @ID(key: .id) var id: UUID?
    @Parent(key: "monitor_id") var monitor: Monitor
    @Field(key: "status_code") var statusCode: Int
    @Field(key: "response_time_ms") var responseTimeMs: Int
    @OptionalField(key: "error") var error: String?
    @Field(key: "status") var status: String
    @Timestamp(key: "checked_at", on: .create) var checkedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        monitorID: UUID,
        statusCode: Int,
        responseTimeMs: Int,
        error: String? = nil,
        status: String
    ) {
        self.id = id
        self.$monitor.id = monitorID
        self.statusCode = statusCode
        self.responseTimeMs = responseTimeMs
        self.error = error
        self.status = status
    }
}

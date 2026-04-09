import Fluent

struct CreateMonitor: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("monitors")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("url", .string, .required)
            .field("interval", .int, .required)
            .field("status", .string, .required)
            .field("last_checked_at", .datetime)
            .field("last_status_change", .datetime)
            .field("consecutive_failures", .int, .required)
            .field("type", .string, .sql(.default("http")))
            .field("heartbeat_token", .string)
            .field("grace_period", .int)
            .field("method", .string, .sql(.default("HEAD")))
            .field("keyword", .string)
            .field("keyword_should_exist", .bool, .sql(.default(true)))
            .field("failure_threshold", .int, .sql(.default(3)))
            .field("ssl_expires_at", .datetime)
            .field("ssl_alert_days", .int, .sql(.default(14)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("monitors").delete()
    }
}

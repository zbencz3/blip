import Fluent

struct CreateMonitorCheck: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("monitor_checks")
            .id()
            .field("monitor_id", .uuid, .required, .references("monitors", "id", onDelete: .cascade))
            .field("status_code", .int, .required)
            .field("response_time_ms", .int, .required)
            .field("error", .string)
            .field("status", .string, .required)
            .field("checked_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("monitor_checks").delete()
    }
}

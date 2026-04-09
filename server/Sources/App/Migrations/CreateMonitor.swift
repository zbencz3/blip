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
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("monitors").delete()
    }
}

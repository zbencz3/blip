import Fluent

struct CreatePendingResponse: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("pending_responses")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("status", .string, .required)
            .field("action_id", .string)
            .field("text", .string)
            .field("device_name", .string)
            .field("created_at", .datetime)
            .field("responded_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("pending_responses").delete()
    }
}

import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("secret", .string, .required)
            .field("status_token", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "secret")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

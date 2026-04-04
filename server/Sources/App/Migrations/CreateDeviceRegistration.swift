import Fluent

struct CreateDeviceRegistration: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("device_registrations")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_token", .string, .required)
            .field("device_name", .string, .required)
            .field("device_secret", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "device_token")
            .unique(on: "device_secret")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("device_registrations").delete()
    }
}

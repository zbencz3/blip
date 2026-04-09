import Fluent

struct AddStatusToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("status_token", .string)
            .update()

        // Generate tokens for existing users
        let users = try await User.query(on: database).all()
        for user in users {
            user.statusToken = User.generateStatusToken()
            try await user.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("status_token")
            .update()
    }
}

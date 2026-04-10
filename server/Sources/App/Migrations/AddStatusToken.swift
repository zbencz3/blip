import Fluent
import SQLKit

struct AddStatusToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }

        // Check if column already exists (CreateUser may have added it)
        let columns = try await sql.raw("PRAGMA table_info(users)").all()
        let existing = Set(columns.compactMap { try? $0.decode(column: "name", as: String.self) })

        if !existing.contains("status_token") {
            try await sql.raw("ALTER TABLE users ADD COLUMN status_token TEXT").run()
        }

        // Generate tokens for existing users that don't have one
        try await sql.raw("""
            UPDATE users SET status_token = hex(randomblob(16))
            WHERE status_token IS NULL
        """).run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }
        try? await sql.raw("ALTER TABLE users DROP COLUMN status_token").run()
    }
}

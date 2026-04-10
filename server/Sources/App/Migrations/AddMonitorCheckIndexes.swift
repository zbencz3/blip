import Fluent
import SQLKit

struct AddMonitorCheckIndexes: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_mc_monitor_checked ON monitor_checks(monitor_id, checked_at)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_mc_checked_at ON monitor_checks(checked_at)").run()
    }

    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }
        try? await sql.raw("DROP INDEX IF EXISTS idx_mc_monitor_checked").run()
        try? await sql.raw("DROP INDEX IF EXISTS idx_mc_checked_at").run()
    }
}

import Fluent
import SQLKit

struct AddMonitorFeatures: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else { return }

        // Add columns only if they don't exist (safe for fresh + existing DBs)
        // SQLite doesn't support IF NOT EXISTS for ALTER TABLE, so check first
        let columns = try await sql.raw("PRAGMA table_info(monitors)").all()
        let existingColumns = Set(columns.compactMap { try? $0.decode(column: "name", as: String.self) })

        if !existingColumns.contains("type") {
            try await sql.raw("ALTER TABLE monitors ADD COLUMN type TEXT NOT NULL DEFAULT 'http'").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN heartbeat_token TEXT").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN grace_period INTEGER").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN method TEXT NOT NULL DEFAULT 'HEAD'").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN keyword TEXT").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN keyword_should_exist INTEGER NOT NULL DEFAULT 1").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN failure_threshold INTEGER NOT NULL DEFAULT 3").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN ssl_expires_at TEXT").run()
            try await sql.raw("ALTER TABLE monitors ADD COLUMN ssl_alert_days INTEGER NOT NULL DEFAULT 14").run()
        }

        let checkColumns = try await sql.raw("PRAGMA table_info(monitor_checks)").all()
        let existingCheckColumns = Set(checkColumns.compactMap { try? $0.decode(column: "name", as: String.self) })

        if !existingCheckColumns.contains("keyword_matched") {
            try await sql.raw("ALTER TABLE monitor_checks ADD COLUMN keyword_matched INTEGER").run()
        }

        // Backfill any existing monitors that have NULL values
        try await sql.raw("""
            UPDATE monitors SET
                type = COALESCE(type, 'http'),
                method = COALESCE(method, 'HEAD'),
                keyword_should_exist = COALESCE(keyword_should_exist, 1),
                failure_threshold = COALESCE(failure_threshold, 3),
                ssl_alert_days = COALESCE(ssl_alert_days, 14)
            WHERE type IS NULL OR method IS NULL OR failure_threshold IS NULL
        """).run()
    }

    func revert(on database: Database) async throws {
        // SQLite doesn't support DROP COLUMN before 3.35.0
        // On older versions this is a no-op
        guard let sql = database as? SQLDatabase else { return }
        for col in ["type", "heartbeat_token", "grace_period", "method", "keyword",
                     "keyword_should_exist", "failure_threshold", "ssl_expires_at", "ssl_alert_days"] {
            try? await sql.raw("ALTER TABLE monitors DROP COLUMN \(unsafeRaw: col)").run()
        }
        try? await sql.raw("ALTER TABLE monitor_checks DROP COLUMN keyword_matched").run()
    }
}

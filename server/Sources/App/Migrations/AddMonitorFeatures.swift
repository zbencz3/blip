import Fluent

struct AddMonitorFeatures: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("monitors")
            .field("type", .string, .sql(.default("http")))
            .field("heartbeat_token", .string)
            .field("grace_period", .int)
            .field("method", .string, .sql(.default("HEAD")))
            .field("keyword", .string)
            .field("keyword_should_exist", .bool, .sql(.default(true)))
            .field("failure_threshold", .int, .sql(.default(3)))
            .field("ssl_expires_at", .datetime)
            .field("ssl_alert_days", .int, .sql(.default(14)))
            .update()

        try await database.schema("monitor_checks")
            .field("keyword_matched", .bool)
            .update()

        // Backfill existing monitors with defaults
        let monitors = try await Monitor.query(on: database).all()
        for monitor in monitors {
            monitor.type = "http"
            monitor.method = "HEAD"
            monitor.keywordShouldExist = true
            monitor.failureThreshold = 3
            monitor.sslAlertDays = 14
            try await monitor.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("monitors")
            .deleteField("type")
            .deleteField("heartbeat_token")
            .deleteField("grace_period")
            .deleteField("method")
            .deleteField("keyword")
            .deleteField("keyword_should_exist")
            .deleteField("failure_threshold")
            .deleteField("ssl_expires_at")
            .deleteField("ssl_alert_days")
            .update()

        try await database.schema("monitor_checks")
            .deleteField("keyword_matched")
            .update()
    }
}

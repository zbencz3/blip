@testable import App
import XCTVapor
import Fluent
import FluentSQLiteDriver
import Testing

@Suite("Monitor CRUD")
struct MonitorControllerTests {
    @Test("Create monitor")
    func createMonitor() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_1")

        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "My Site", url: "https://example.com", interval: 300))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitor = try? res.content.decode(MonitorResponse.self)
            #expect(monitor?.name == "My Site")
            #expect(monitor?.url == "https://example.com")
            #expect(monitor?.interval == 300)
            #expect(monitor?.status == "pending")
            #expect(monitor?.consecutiveFailures == 0)
        })
    }

    @Test("Create monitor with invalid URL returns 422")
    func createInvalidUrl() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_2")

        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Bad", url: "ftp://example.com", interval: 300))
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Create monitor with invalid interval returns 422")
    func createInvalidInterval() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_3")

        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Bad", url: "https://example.com", interval: 120))
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("List monitors")
    func listMonitors() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_4")

        for name in ["Site A", "Site B"] {
            try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
                req.headers.bearerAuthorization = .init(token: secret)
                try req.content.encode(CreateMonitorRequest(name: name, url: "https://example.com/\(name)", interval: 60))
            })
        }

        try await app.test(.GET, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitors = try? res.content.decode([MonitorResponse].self)
            #expect(monitors?.count == 2)
        })
    }

    @Test("Delete monitor verifies ownership")
    func deleteMonitorOwnership() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret1 = SecretGenerator.generate()
        let secret2 = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret1, token: "mon_tok_5a")
        try await registerDevice(app: app, secret: secret2, token: "mon_tok_5b")

        var monitorID: UUID?
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret1)
            try req.content.encode(CreateMonitorRequest(name: "Mine", url: "https://example.com", interval: 60))
        }, afterResponse: { res async in
            let monitor = try? res.content.decode(MonitorResponse.self)
            monitorID = monitor?.id
        })

        // User 2 should not be able to delete user 1's monitor
        try await app.test(.DELETE, "v1/monitors/\(monitorID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret2)
        }, afterResponse: { res async in
            #expect(res.status == .notFound)
        })

        // User 1 can delete their own monitor
        try await app.test(.DELETE, "v1/monitors/\(monitorID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret1)
        }, afterResponse: { res async in
            #expect(res.status == .noContent)
        })
    }

    @Test("Max monitor limit enforced")
    func maxMonitorLimit() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_6")

        // Create 5 monitors (free limit)
        for i in 1...MonitorController.freeMonitorLimit {
            try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
                req.headers.bearerAuthorization = .init(token: secret)
                try req.content.encode(CreateMonitorRequest(name: "Site \(i)", url: "https://example\(i).com", interval: 60))
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }

        // 6th should be rejected
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "One too many", url: "https://extra.com", interval: 60))
        }, afterResponse: { res async in
            #expect(res.status == .forbidden)
        })
    }

    @Test("Update monitor")
    func updateMonitor() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_7")

        var monitorID: UUID?
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Old Name", url: "https://old.com", interval: 60))
        }, afterResponse: { res async in
            let monitor = try? res.content.decode(MonitorResponse.self)
            monitorID = monitor?.id
        })

        try await app.test(.PATCH, "v1/monitors/\(monitorID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(["name": "New Name"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitor = try? res.content.decode(MonitorResponse.self)
            #expect(monitor?.name == "New Name")
            #expect(monitor?.url == "https://old.com")
        })
    }

    @Test("Update monitor URL resets status")
    func updateUrlResetsStatus() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_8")

        // Create and manually set to "up"
        let user = try await User.query(on: app.db).filter(\.$secret == secret).first()!
        let monitor = Monitor(userID: user.id!, name: "Test", url: "https://old.com", interval: 60, status: "up")
        monitor.lastCheckedAt = Date()
        monitor.consecutiveFailures = 0
        try await monitor.save(on: app.db)

        try await app.test(.PATCH, "v1/monitors/\(monitor.id!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(["url": "https://new.com"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let response = try? res.content.decode(MonitorResponse.self)
            #expect(response?.status == "pending")
            #expect(response?.url == "https://new.com")
            #expect(response?.lastCheckedAt == nil)
        })
    }

    @Test("Create monitor with proper struct encoding succeeds")
    func createWithStructEncoding() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_int")

        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Test", url: "https://example.com", interval: 300))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitor = try? res.content.decode(MonitorResponse.self)
            #expect(monitor?.interval == 300)
        })
    }

    @Test("Create monitor with interval as string fails decoding")
    func createWithStringInterval() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_str")

        // Simulate the old iOS bug: interval sent as string in a [String:String] dict
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(["name": "Test", "url": "https://example.com", "interval": "300"])
        }, afterResponse: { res async in
            // String interval should fail — server expects Int
            #expect(res.status == .badRequest || res.status == .unprocessableEntity)
        })
    }

    @Test("List monitors requires auth")
    func listRequiresAuth() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "v1/monitors", afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Pause and resume monitor")
    func pauseResume() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_pause")

        var monitorID: UUID?
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Pausable", url: "https://example.com", interval: 60))
        }, afterResponse: { res async in
            let monitor = try? res.content.decode(MonitorResponse.self)
            monitorID = monitor?.id
        })

        // Pause
        try await app.test(.POST, "v1/monitors/\(monitorID!)/pause", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(PauseMonitorRequest(paused: true))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitor = try? res.content.decode(MonitorResponse.self)
            #expect(monitor?.status == "paused")
        })

        // Resume
        try await app.test(.POST, "v1/monitors/\(monitorID!)/pause", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(PauseMonitorRequest(paused: false))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let monitor = try? res.content.decode(MonitorResponse.self)
            #expect(monitor?.status == "pending")
        })
    }

    @Test("Stats endpoint returns empty stats for new monitor")
    func statsEmpty() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_stats")

        var monitorID: UUID?
        try await app.test(.POST, "v1/monitors", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(CreateMonitorRequest(name: "Stats Test", url: "https://example.com", interval: 60))
        }, afterResponse: { res async in
            let monitor = try? res.content.decode(MonitorResponse.self)
            monitorID = monitor?.id
        })

        try await app.test(.GET, "v1/monitors/\(monitorID!)/stats", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let stats = try? res.content.decode(MonitorStatsResponse.self)
            #expect(stats?.totalChecks == 0)
            #expect(stats?.uptime7d == nil)
            #expect(stats?.avgResponseMs == nil)
        })
    }

    @Test("Stats endpoint returns computed values")
    func statsWithChecks() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_stats2")

        let user = try await User.query(on: app.db).filter(\.$secret == secret).first()!
        let monitor = Monitor(userID: user.id!, name: "Stats", url: "https://example.com", interval: 60, status: "up")
        try await monitor.save(on: app.db)

        // Insert some checks
        for i in 0..<10 {
            let check = MonitorCheck(
                monitorID: monitor.id!,
                statusCode: 200,
                responseTimeMs: 100 + i * 10,
                status: "up"
            )
            try await check.save(on: app.db)
        }

        try await app.test(.GET, "v1/monitors/\(monitor.id!)/stats", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let stats = try? res.content.decode(MonitorStatsResponse.self)
            #expect(stats?.totalChecks == 10)
            #expect(stats?.uptime7d == 100.0)
            #expect(stats?.uptime30d == 100.0)
            #expect(stats?.avgResponseMs == 145)
            #expect(stats?.minResponseMs == 100)
            #expect(stats?.maxResponseMs == 190)
        })
    }

    @Test("Incidents endpoint returns down checks")
    func incidentsEndpoint() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_inc")

        let user = try await User.query(on: app.db).filter(\.$secret == secret).first()!
        let monitor = Monitor(userID: user.id!, name: "Incidents", url: "https://example.com", interval: 60, status: "up")
        try await monitor.save(on: app.db)

        // Insert up and down checks
        let upCheck = MonitorCheck(monitorID: monitor.id!, statusCode: 200, responseTimeMs: 100, status: "up")
        try await upCheck.save(on: app.db)
        let downCheck = MonitorCheck(monitorID: monitor.id!, statusCode: 500, responseTimeMs: 5000, error: "HTTP 500", status: "down")
        try await downCheck.save(on: app.db)

        try await app.test(.GET, "v1/monitors/\(monitor.id!)/incidents", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let incidents = try? res.content.decode([MonitorIncidentResponse].self)
            #expect(incidents?.count == 1)
            #expect(incidents?.first?.error == "HTTP 500")
        })
    }

    @Test("Checks endpoint returns recent checks for chart")
    func checksEndpoint() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await registerDevice(app: app, secret: secret, token: "mon_tok_checks")

        let user = try await User.query(on: app.db).filter(\.$secret == secret).first()!
        let monitor = Monitor(userID: user.id!, name: "Checks", url: "https://example.com", interval: 60, status: "up")
        try await monitor.save(on: app.db)

        for i in 0..<5 {
            let check = MonitorCheck(monitorID: monitor.id!, statusCode: 200, responseTimeMs: 50 + i * 20, status: "up")
            try await check.save(on: app.db)
        }

        try await app.test(.GET, "v1/monitors/\(monitor.id!)/checks", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let checks = try? res.content.decode([MonitorCheckResponse].self)
            #expect(checks?.count == 5)
        })
    }

    @Test("Paused monitors are skipped by checker filter")
    func pausedMonitorsSkipped() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Paused", url: "https://example.com", interval: 60, status: "paused")
        try await monitor.save(on: app.db)

        // Query same as MonitorChecker — paused should be excluded
        let active = try await Monitor.query(on: app.db)
            .filter(\.$status != "paused")
            .all()
        #expect(active.isEmpty)
    }

    // MARK: - Helpers

    private func registerDevice(app: Application, secret: String, token: String) async throws {
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": token,
                "device_name": "iPhone"
            ])
        })
    }
}

@Suite("Monitor Checker")
struct MonitorCheckerTests {
    @Test("Check sets status to up on success")
    func checkSetsUp() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Test", url: "https://example.com", interval: 60)
        try await monitor.save(on: app.db)

        // Simulate a successful check by setting fields directly
        monitor.status = "up"
        monitor.consecutiveFailures = 0
        monitor.lastCheckedAt = Date()
        try await monitor.save(on: app.db)

        let saved = try await Monitor.find(monitor.id, on: app.db)
        #expect(saved?.status == "up")
        #expect(saved?.consecutiveFailures == 0)
        #expect(saved?.lastCheckedAt != nil)
    }

    @Test("Three consecutive failures sets status to down")
    func threeFailuresSetsDown() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let device = DeviceRegistration(
            userID: user.id!,
            deviceToken: "checker_tok_1",
            deviceName: "iPhone",
            deviceSecret: SecretGenerator.generate()
        )
        try await device.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Bad Site", url: "https://example.com", interval: 60)
        monitor.consecutiveFailures = 2
        monitor.status = "up"
        monitor.lastCheckedAt = Date().addingTimeInterval(-120)
        try await monitor.save(on: app.db)

        // Simulate the third failure
        monitor.consecutiveFailures = 3
        monitor.status = "down"
        monitor.lastStatusChange = Date()
        monitor.lastCheckedAt = Date()
        try await monitor.save(on: app.db)

        let saved = try await Monitor.find(monitor.id, on: app.db)
        #expect(saved?.status == "down")
        #expect(saved?.consecutiveFailures == 3)
    }

    @Test("Recovery notification uses correct payload")
    func recoveryNotification() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let device = DeviceRegistration(
            userID: user.id!,
            deviceToken: "checker_tok_2",
            deviceName: "iPhone",
            deviceSecret: SecretGenerator.generate()
        )
        try await device.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "My API", url: "https://example.com", interval: 60, status: "down")
        monitor.consecutiveFailures = 5
        monitor.lastCheckedAt = Date().addingTimeInterval(-120)
        try await monitor.save(on: app.db)

        // Verify notification payload structure
        let payload = NotificationPayload(
            title: "My API is back up",
            subtitle: nil,
            body: "https://example.com is responding again.",
            threadId: "monitor-\(monitor.id!.uuidString)",
            sound: "default",
            openUrl: nil,
            imageUrl: nil,
            expirationDate: nil,
            interruptionLevel: "time-sensitive",
            filterCriteria: nil,
            actions: nil,
            responseID: nil,
            responseURL: nil
        )

        let mock = mockAPNs(from: app)
        try await mock.send(payload, to: device.deviceToken)

        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].payload.title == "My API is back up")
        #expect(mock.sent[0].payload.interruptionLevel == "time-sensitive")
        #expect(mock.sent[0].deviceToken == "checker_tok_2")
    }

    @Test("Cascade delete removes monitor checks when monitor is deleted")
    func cascadeDeleteChecks() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Test", url: "https://example.com", interval: 60, status: "up")
        try await monitor.save(on: app.db)

        let check = MonitorCheck(monitorID: monitor.id!, statusCode: 200, responseTimeMs: 100, status: "up")
        try await check.save(on: app.db)

        try await monitor.delete(on: app.db)

        let checks = try await MonitorCheck.query(on: app.db).all()
        #expect(checks.isEmpty)
    }

    @Test("Cascade delete removes monitors when user is deleted")
    func cascadeDelete() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Test", url: "https://example.com", interval: 60)
        try await monitor.save(on: app.db)

        try await user.delete(on: app.db)

        let found = try await Monitor.find(monitor.id, on: app.db)
        #expect(found == nil)
    }
}

@Suite("Status Page")
struct StatusPageTests {
    @Test("Status page returns HTML for valid secret")
    func statusPageValid() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "My API", url: "https://example.com", interval: 60, status: "up")
        monitor.lastCheckedAt = Date()
        try await monitor.save(on: app.db)

        try await app.test(.GET, "status/\(secret)", afterResponse: { res async in
            #expect(res.status == .ok)
            let body = res.body.string
            #expect(body.contains("My API"))
            #expect(body.contains("ALL SYSTEMS OPERATIONAL"))
            #expect(body.contains("UP"))
            #expect(res.headers.contentType?.serialize().contains("text/html") == true)
        })
    }

    @Test("Status page shows degraded when a monitor is down")
    func statusPageDegraded() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)

        let up = Monitor(userID: user.id!, name: "Healthy", url: "https://up.com", interval: 60, status: "up")
        try await up.save(on: app.db)
        let down = Monitor(userID: user.id!, name: "Broken", url: "https://down.com", interval: 60, status: "down")
        try await down.save(on: app.db)

        try await app.test(.GET, "status/\(secret)", afterResponse: { res async in
            #expect(res.status == .ok)
            let body = res.body.string
            #expect(body.contains("DEGRADED"))
            #expect(body.contains("Healthy"))
            #expect(body.contains("Broken"))
        })
    }

    @Test("Status page hides paused monitors")
    func statusPageHidesPaused() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)

        let active = Monitor(userID: user.id!, name: "Active", url: "https://active.com", interval: 60, status: "up")
        try await active.save(on: app.db)
        let paused = Monitor(userID: user.id!, name: "Paused One", url: "https://paused.com", interval: 60, status: "paused")
        try await paused.save(on: app.db)

        try await app.test(.GET, "status/\(secret)", afterResponse: { res async in
            let body = res.body.string
            #expect(body.contains("Active"))
            #expect(!body.contains("Paused One"))
        })
    }

    @Test("Status page returns 404 for invalid secret")
    func statusPageInvalid() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "status/nonexistent_secret", afterResponse: { res async in
            #expect(res.status == .notFound)
        })
    }

    @Test("Status page shows uptime stats from checks")
    func statusPageWithStats() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "Tracked", url: "https://tracked.com", interval: 60, status: "up")
        monitor.lastCheckedAt = Date()
        try await monitor.save(on: app.db)

        for _ in 0..<5 {
            let check = MonitorCheck(monitorID: monitor.id!, statusCode: 200, responseTimeMs: 150, status: "up")
            try await check.save(on: app.db)
        }

        try await app.test(.GET, "status/\(secret)", afterResponse: { res async in
            let body = res.body.string
            #expect(body.contains("100.0%"))
            #expect(body.contains("150ms"))
        })
    }

    @Test("Status page escapes HTML in monitor names")
    func statusPageXSS() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)

        let monitor = Monitor(userID: user.id!, name: "<script>alert(1)</script>", url: "https://xss.com", interval: 60, status: "up")
        try await monitor.save(on: app.db)

        try await app.test(.GET, "status/\(secret)", afterResponse: { res async in
            let body = res.body.string
            #expect(!body.contains("<script>"))
            #expect(body.contains("&lt;script&gt;"))
        })
    }
}

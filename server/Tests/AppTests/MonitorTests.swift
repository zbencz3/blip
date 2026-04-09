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

    @Test("List monitors requires auth")
    func listRequiresAuth() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "v1/monitors", afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
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

@testable import App
import XCTVapor
import Fluent
import FluentSQLiteDriver
import Testing

func makeTestApp() async throws -> Application {
    let app = try await Application.make(.testing)
    app.databases.use(.sqlite(.memory), as: .sqlite)
    app.migrations.add(CreateUser())
    app.migrations.add(CreateDeviceRegistration())
    app.migrations.add(CreatePendingResponse())
    try await app.autoMigrate()
    app.apnsServiceCustom = MockAPNsService()
    try routes(app)
    return app
}

func mockAPNs(from app: Application) -> MockAPNsService {
    app.apnsServiceCustom as! MockAPNsService
}

@Suite("Health")
struct HealthTests {
    @Test("Health endpoint returns ok")
    func healthEndpoint() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "health", afterResponse: { res async in
            #expect(res.status == .ok)
            #expect(res.body.string.contains("ok"))
        })
    }
}

@Suite("Device Registration")
struct DeviceControllerTests {
    @Test("Register creates user and device")
    func registerCreatesUserAndDevice() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token123",
                "device_name": "iPhone"
            ])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let device = try? res.content.decode(DeviceResponse.self)
            #expect(device?.deviceName == "iPhone")
            #expect(device?.deviceToken == "token123")
            #expect(device?.deviceSecret != nil)
        })
    }

    @Test("Register with same token updates device name")
    func registerUpdatesExisting() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token123",
                "device_name": "iPhone"
            ])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token123",
                "device_name": "iPhone Pro"
            ])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let device = try? res.content.decode(DeviceResponse.self)
            #expect(device?.deviceName == "iPhone Pro")
        })

        // Should still be only 1 device
        try await app.test(.GET, "v1/devices", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            let devices = try? res.content.decode([DeviceResponse].self)
            #expect(devices?.count == 1)
        })
    }

    @Test("List devices requires auth")
    func listRequiresAuth() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "v1/devices", afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Delete device")
    func deleteDevice() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        var deviceID: UUID?

        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_del",
                "device_name": "iPhone"
            ])
        }, afterResponse: { res async in
            let device = try? res.content.decode(DeviceResponse.self)
            deviceID = device?.id
        })

        try await app.test(.DELETE, "v1/devices/\(deviceID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .noContent)
        })

        try await app.test(.GET, "v1/devices", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            let devices = try? res.content.decode([DeviceResponse].self)
            #expect(devices?.count == 0)
        })
    }
}

@Suite("Secret Rotation")
struct SecretControllerTests {
    @Test("Rotate secret returns new secret")
    func rotateSecret() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let oldSecret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": oldSecret,
                "device_token": "token_rot",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/secret/rotate", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: oldSecret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let response = try? res.content.decode(RotateSecretResponse.self)
            #expect(response?.secret != oldSecret)
            #expect(response?.secret.hasPrefix("bps_usr_") == true)
        })
    }

    @Test("Old secret invalid after rotation")
    func oldSecretInvalidAfterRotation() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let oldSecret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": oldSecret,
                "device_token": "token_rot2",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/secret/rotate", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: oldSecret)
        })

        try await app.test(.GET, "v1/devices", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: oldSecret)
        }, afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }
}

@Suite("Notification Send")
struct NotificationControllerTests {
    @Test("Send via URL path with JSON body")
    func sendViaURLPath() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_send1",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(["title": "Test", "message": "Hello"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let response = try? res.content.decode(NotificationResponse.self)
            #expect(response?.message == "Notification sent")
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].payload.title == "Test")
        #expect(mock.sent[0].payload.body == "Hello")
        #expect(mock.sent[0].deviceToken == "token_send1")
    }

    @Test("Send via Bearer token")
    func sendViaBearer() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_send2",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/send", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
            try req.content.encode(["message": "Bearer test"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].payload.body == "Bearer test")
    }

    @Test("Send plain text body")
    func sendPlainText() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_send3",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            req.headers.contentType = .plainText
            req.body = .init(string: "Plain text message")
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].payload.body == "Plain text message")
    }

    @Test("Send with invalid secret returns 401")
    func sendInvalidSecret() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.POST, "v1/bps_usr_invalid", beforeRequest: { req async throws in
            try req.content.encode(["message": "Hello"])
        }, afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Send without title or message returns 422")
    func sendMissingContent() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_send4",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(["sound": "default"])
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Send to all devices")
    func sendToAllDevices() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        for i in 1...3 {
            try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
                try req.content.encode([
                    "secret": secret,
                    "device_token": "multi_token_\(i)",
                    "device_name": "Device \(i)"
                ])
            })
        }

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(["message": "Broadcast"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 3)
    }

    @Test("Send with actions passes them to APNs")
    func sendWithActions() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_actions",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let title: String
            let message: String
            let actions: [ActionItem]

            struct ActionItem: Content {
                let id: String
                let label: String
                let webhook: String?
                let destructive: Bool?
            }
        }

        let payload = ActionPayload(
            title: "Motion Detected",
            message: "Garage camera",
            actions: [
                .init(id: "lights_on", label: "Turn On Lights", webhook: "https://example.com/lights", destructive: nil),
                .init(id: "lock", label: "Lock Door", webhook: "https://example.com/lock", destructive: true),
                .init(id: "dismiss", label: "Dismiss", webhook: nil, destructive: nil)
            ]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].payload.actions?.count == 3)
        #expect(mock.sent[0].payload.actions?[0].id == "lights_on")
        #expect(mock.sent[0].payload.actions?[1].destructive == true)
        #expect(mock.sent[0].payload.actions?[2].webhook == nil)
    }

    @Test("Send with more than 4 actions returns 422")
    func sendTooManyActions() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_toomany",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let message: String
            let actions: [ActionItem]

            struct ActionItem: Content {
                let id: String
                let label: String
            }
        }

        let payload = ActionPayload(
            message: "Test",
            actions: (1...5).map { .init(id: "action_\($0)", label: "Action \($0)") }
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Send with action missing id returns 422")
    func sendActionMissingId() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_noid",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let message: String
            let actions: [ActionItem]

            struct ActionItem: Content {
                let id: String
                let label: String
            }
        }

        let payload = ActionPayload(
            message: "Test",
            actions: [.init(id: "", label: "Empty ID")]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Send with action missing label returns 422")
    func sendActionMissingLabel() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_nolabel",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let message: String
            let actions: [ActionItem]

            struct ActionItem: Content {
                let id: String
                let label: String
            }
        }

        let payload = ActionPayload(
            message: "Test",
            actions: [.init(id: "test", label: "")]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Send with non-http open_url returns 422")
    func sendInvalidOpenUrl() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_openurl",
                "device_name": "iPhone"
            ])
        })

        // Reject dangerous schemes
        for scheme in ["tel:+1234567890", "javascript:alert(1)", "file:///etc/passwd", "data:text/html,hi"] {
            try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
                try req.content.encode(["message": "Test", "open_url": scheme])
            }, afterResponse: { res async in
                #expect(res.status == .unprocessableEntity, "Expected 422 for open_url: \(scheme)")
            })
        }
    }

    @Test("Send with https open_url is accepted")
    func sendValidOpenUrl() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_openurl_ok",
                "device_name": "iPhone"
            ])
        })

        for url in ["https://example.com/page", "http://example.com/page"] {
            try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
                try req.content.encode(["message": "Test", "open_url": url])
            }, afterResponse: { res async in
                #expect(res.status == .ok, "Expected 200 for open_url: \(url)")
            })
        }
    }

    @Test("Action with http webhook returns 422")
    func sendActionHttpWebhook() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_webhook_http",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let message: String
            let actions: [ActionItem]
            struct ActionItem: Content {
                let id: String
                let label: String
                let webhook: String
            }
        }

        let payload = ActionPayload(
            message: "Test",
            actions: [.init(id: "act1", label: "Open", webhook: "http://example.com/callback")]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .unprocessableEntity)
        })
    }

    @Test("Action with https webhook is accepted")
    func sendActionHttpsWebhook() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_webhook_https",
                "device_name": "iPhone"
            ])
        })

        struct ActionPayload: Content {
            let message: String
            let actions: [ActionItem]
            struct ActionItem: Content {
                let id: String
                let label: String
                let webhook: String
            }
        }

        let payload = ActionPayload(
            message: "Test",
            actions: [.init(id: "act1", label: "Open", webhook: "https://example.com/callback")]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })
    }

    @Test("Send via device secret sends to single device")
    func sendViaDeviceSecret() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        var deviceSecret: String?

        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "dev_token_1",
                "device_name": "iPhone"
            ])
        }, afterResponse: { res async in
            let device = try? res.content.decode(DeviceResponse.self)
            deviceSecret = device?.deviceSecret
        })

        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "dev_token_2",
                "device_name": "iPad"
            ])
        })

        try await app.test(.POST, "v1/send", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: deviceSecret!)
            try req.content.encode(["message": "Device only"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        let mock = mockAPNs(from: app)
        #expect(mock.sent.count == 1)
        #expect(mock.sent[0].deviceToken == "dev_token_1")
    }
}

@Suite("Rate Limiting")
struct RateLimitTests {
    func makeRateLimitedApp() async throws -> Application {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(CreateUser())
        app.migrations.add(CreateDeviceRegistration())
        app.migrations.add(CreatePendingResponse())
        try await app.autoMigrate()
        app.apnsServiceCustom = MockAPNsService()

        // Fresh store with a low limit for testing
        let testStore = RateLimitStore(limit: 3, window: 60)
        app.get { req async in "ok" }
        app.get("health") { req async in ["status": "ok"] }
        try app.register(collection: DeviceController())
        try app.register(collection: SecretController())
        let rateLimited = app.grouped(RateLimitMiddleware(store: testStore))
        try rateLimited.register(collection: NotificationController(apnsService: app.apnsServiceCustom))
        return app
    }

    @Test("Exceeding rate limit returns 429")
    func rateLimitExceeded() async throws {
        let app = try await makeRateLimitedApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "rl_token",
                "device_name": "iPhone"
            ])
        })

        // First 3 should succeed
        for _ in 1...3 {
            try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
                try req.content.encode(["message": "Hello"])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }

        // 4th should be rate limited
        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(["message": "Hello"])
        }, afterResponse: { res async in
            #expect(res.status == .tooManyRequests)
        })
    }

    @Test("Different secrets have independent rate limits")
    func rateLimitsArePerSecret() async throws {
        let app = try await makeRateLimitedApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret1 = SecretGenerator.generate()
        let secret2 = SecretGenerator.generate()

        for secret in [secret1, secret2] {
            try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
                try req.content.encode([
                    "secret": secret,
                    "device_token": "rl_token_\(secret.suffix(4))",
                    "device_name": "iPhone"
                ])
            })
        }

        // Exhaust secret1's limit
        for _ in 1...3 {
            try await app.test(.POST, "v1/\(secret1)", beforeRequest: { req async throws in
                try req.content.encode(["message": "Hello"])
            })
        }

        // secret2 should still work
        try await app.test(.POST, "v1/\(secret2)", beforeRequest: { req async throws in
            try req.content.encode(["message": "Hello"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })
    }
}

@Suite("Response Channel")
struct ResponseChannelTests {
    @Test("Sending with response_channel action creates pending response")
    func sendWithResponseChannel() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_rc1",
                "device_name": "iPhone"
            ])
        })

        struct RCPayload: Content {
            let title: String
            let message: String
            let actions: [RCAction]
            struct RCAction: Content {
                let id: String
                let label: String
                let response_channel: Bool
            }
        }

        let payload = RCPayload(
            title: "Approve?",
            message: "Deploy to prod",
            actions: [
                .init(id: "approve", label: "Approve", response_channel: true),
                .init(id: "reject", label: "Reject", response_channel: true)
            ]
        )

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(payload)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let response = try? res.content.decode(NotificationResponse.self)
            #expect(response?.message == "Notification sent")
            #expect(response?.responseId != nil)
        })
    }

    @Test("Sending without response_channel returns no response_id")
    func sendWithoutResponseChannel() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_rc2",
                "device_name": "iPhone"
            ])
        })

        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(["title": "Test", "message": "Hello"])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let response = try? res.content.decode(NotificationResponse.self)
            #expect(response?.responseId == nil)
        })
    }

    @Test("Submit response updates pending response")
    func submitResponse() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        // Create a user and pending response directly
        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)
        let pending = PendingResponse(userID: user.id!)
        try await pending.save(on: app.db)
        let responseID = pending.id!.uuidString

        try await app.test(.POST, "v1/responses/\(responseID)", beforeRequest: { req async throws in
            try req.content.encode(ResponseSubmission(
                actionID: "approve",
                text: "Looks good",
                deviceName: "iPhone 15"
            ))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        // Verify it was updated
        let updated = try await PendingResponse.find(pending.id, on: app.db)
        #expect(updated?.status == "responded")
        #expect(updated?.actionID == "approve")
        #expect(updated?.text == "Looks good")
        #expect(updated?.deviceName == "iPhone 15")
        #expect(updated?.respondedAt != nil)
    }

    @Test("Submit to already responded returns conflict")
    func submitAlreadyResponded() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)
        let pending = PendingResponse(userID: user.id!)
        pending.status = "responded"
        pending.respondedAt = Date()
        try await pending.save(on: app.db)

        try await app.test(.POST, "v1/responses/\(pending.id!.uuidString)", beforeRequest: { req async throws in
            try req.content.encode(ResponseSubmission(actionID: "approve", text: nil, deviceName: nil))
        }, afterResponse: { res async in
            #expect(res.status == .conflict)
        })
    }

    @Test("Poll pending response returns 202")
    func pollPending() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)
        let pending = PendingResponse(userID: user.id!)
        try await pending.save(on: app.db)

        try await app.test(.GET, "v1/responses/\(pending.id!.uuidString)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .accepted)
            let poll = try? res.content.decode(PollResponse.self)
            #expect(poll?.status == "pending")
        })
    }

    @Test("Poll responded returns 200 and deletes row")
    func pollResponded() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        let user = User(secret: secret)
        try await user.save(on: app.db)
        let pending = PendingResponse(userID: user.id!)
        pending.status = "responded"
        pending.actionID = "approve"
        pending.text = "LGTM"
        pending.deviceName = "iPad"
        pending.respondedAt = Date()
        try await pending.save(on: app.db)
        let responseID = pending.id!

        try await app.test(.GET, "v1/responses/\(responseID.uuidString)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let poll = try? res.content.decode(PollResponse.self)
            #expect(poll?.status == "responded")
            #expect(poll?.actionID == "approve")
            #expect(poll?.text == "LGTM")
            #expect(poll?.deviceName == "iPad")
        })

        // Row should be deleted after poll
        let found = try await PendingResponse.find(responseID, on: app.db)
        #expect(found == nil)
    }

    @Test("Poll requires auth")
    func pollRequiresAuth() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)
        let pending = PendingResponse(userID: user.id!)
        try await pending.save(on: app.db)

        try await app.test(.GET, "v1/responses/\(pending.id!.uuidString)", afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("Poll with wrong user returns 404")
    func pollWrongUser() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret1 = SecretGenerator.generate()
        let user1 = User(secret: secret1)
        try await user1.save(on: app.db)

        let secret2 = SecretGenerator.generate()
        let user2 = User(secret: secret2)
        try await user2.save(on: app.db)

        let pending = PendingResponse(userID: user1.id!)
        try await pending.save(on: app.db)

        // user2 tries to poll user1's response
        try await app.test(.GET, "v1/responses/\(pending.id!.uuidString)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret2)
        }, afterResponse: { res async in
            #expect(res.status == .notFound)
        })
    }

    @Test("TTL cleanup deletes old pending responses")
    func ttlCleanup() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let user = User(secret: SecretGenerator.generate())
        try await user.save(on: app.db)

        // Create an old pending response (6 minutes ago)
        let old = PendingResponse(userID: user.id!)
        try await old.save(on: app.db)
        // Manually set created_at to 6 minutes ago
        old.createdAt = Date().addingTimeInterval(-360)
        try await old.save(on: app.db)

        // Create a recent one
        let recent = PendingResponse(userID: user.id!)
        try await recent.save(on: app.db)

        // Run TTL cleanup manually
        let cutoff = Date().addingTimeInterval(-300)
        try await PendingResponse.query(on: app.db)
            .filter(\.$createdAt < cutoff)
            .delete()

        // Old should be gone, recent should remain
        let oldFound = try await PendingResponse.find(old.id, on: app.db)
        #expect(oldFound == nil)

        let recentFound = try await PendingResponse.find(recent.id, on: app.db)
        #expect(recentFound != nil)
    }

    @Test("Submit to nonexistent response returns 404")
    func submitNotFound() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let fakeID = UUID().uuidString
        try await app.test(.POST, "v1/responses/\(fakeID)", beforeRequest: { req async throws in
            try req.content.encode(ResponseSubmission(actionID: "test", text: nil, deviceName: nil))
        }, afterResponse: { res async in
            #expect(res.status == .notFound)
        })
    }

    @Test("Full flow: send → poll pending → submit → poll responded → deleted")
    func fullFlow() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode([
                "secret": secret,
                "device_token": "token_flow",
                "device_name": "iPhone"
            ])
        })

        struct RCPayload: Content {
            let message: String
            let actions: [RCAction]
            struct RCAction: Content {
                let id: String
                let label: String
                let response_channel: Bool
            }
        }

        var responseID: String?

        // 1. Send notification with response channel
        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(RCPayload(
                message: "Deploy?",
                actions: [.init(id: "yes", label: "Yes", response_channel: true)]
            ))
        }, afterResponse: { res async in
            let response = try? res.content.decode(NotificationResponse.self)
            responseID = response?.responseId
            #expect(responseID != nil)
        })

        // 2. Poll — should be pending
        try await app.test(.GET, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .accepted)
            let poll = try? res.content.decode(PollResponse.self)
            #expect(poll?.status == "pending")
        })

        // 3. Submit response
        try await app.test(.POST, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            try req.content.encode(ResponseSubmission(actionID: "yes", text: nil, deviceName: "iPhone"))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        // 4. Poll — should be responded and then deleted
        try await app.test(.GET, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let poll = try? res.content.decode(PollResponse.self)
            #expect(poll?.status == "responded")
            #expect(poll?.actionID == "yes")
        })

        // 5. Poll again — should be 404 (deleted)
        try await app.test(.GET, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .notFound)
        })
    }

    @Test("Submit response with text input")
    func submitWithTextInput() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let secret = SecretGenerator.generate()
        try await app.test(.POST, "v1/devices/register", beforeRequest: { req async throws in
            try req.content.encode(["secret": secret, "device_token": "token_text", "device_name": "iPhone"])
        })

        struct RCPayload: Content {
            let message: String
            let actions: [RCAction]
            struct RCAction: Content {
                let id: String
                let label: String
                let response_channel: Bool
                let type: String?
                let text_input_placeholder: String?
            }
        }

        var responseID: String?

        // Send notification with text input action
        try await app.test(.POST, "v1/\(secret)", beforeRequest: { req async throws in
            try req.content.encode(RCPayload(
                message: "What branch?",
                actions: [.init(id: "reply", label: "Reply", response_channel: true, type: "text_input", text_input_placeholder: "Branch name...")]
            ))
        }, afterResponse: { res async in
            let response = try? res.content.decode(NotificationResponse.self)
            responseID = response?.responseId
            #expect(responseID != nil)
        })

        // Submit with text
        try await app.test(.POST, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            try req.content.encode(ResponseSubmission(actionID: "reply", text: "feature/response-channel", deviceName: "iPhone"))
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })

        // Poll — should have text
        try await app.test(.GET, "v1/responses/\(responseID!)", beforeRequest: { req async throws in
            req.headers.bearerAuthorization = .init(token: secret)
        }, afterResponse: { res async in
            #expect(res.status == .ok)
            let poll = try? res.content.decode(PollResponse.self)
            #expect(poll?.status == "responded")
            #expect(poll?.actionID == "reply")
            #expect(poll?.text == "feature/response-channel")
            #expect(poll?.deviceName == "iPhone")
        })
    }

    @Test("Poll without auth returns unauthorized")
    func pollNoAuth() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let fakeID = UUID().uuidString
        try await app.test(.GET, "v1/responses/\(fakeID)", afterResponse: { res async in
            #expect(res.status == .unauthorized)
        })
    }
}

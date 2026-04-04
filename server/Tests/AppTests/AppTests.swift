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
            #expect(response?.secret.hasPrefix("blp_usr_") == true)
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

        try await app.test(.POST, "v1/blp_usr_invalid", beforeRequest: { req async throws in
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

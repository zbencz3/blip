import Vapor
import Fluent
import FluentSQLiteDriver
import APNSCore
import VaporAPNS
import APNS
import Crypto

func configure(_ app: Application) async throws {
    let dbPath = Environment.get("DB_PATH") ?? (app.environment == .production ? "/data/db.sqlite" : "db.sqlite")
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateDeviceRegistration())
    app.migrations.add(CreatePendingResponse())
    app.migrations.add(CreateMonitor())
    try await app.autoMigrate()

    configureAPNs(app)

    // TTL cleanup: delete pending responses older than 5 minutes
    app.eventLoopGroup.next().scheduleRepeatedTask(initialDelay: .seconds(60), delay: .seconds(60)) { _ in
        Task {
            let cutoff = Date().addingTimeInterval(-300)
            try? await PendingResponse.query(on: app.db)
                .filter(\.$createdAt < cutoff)
                .delete()
        }
    }

    // Monitor checker: runs every 30 seconds
    app.eventLoopGroup.next().scheduleRepeatedTask(initialDelay: .seconds(30), delay: .seconds(30)) { _ in
        Task {
            await MonitorChecker.checkAll(app: app)
        }
    }

    try routes(app)
}

private func configureAPNs(_ app: Application) {
    guard let keyID = Environment.get("APNS_KEY_ID"),
          let teamID = Environment.get("APNS_TEAM_ID")
    else {
        app.logger.warning("APNs not configured — using mock service. Set APNS_KEY_ID, APNS_TEAM_ID, and APNS_PRIVATE_KEY or APNS_KEY_PATH to enable.")
        app.apnsServiceCustom = MockAPNsService()
        return
    }

    // Accept key as inline env var (APNS_PRIVATE_KEY) or file path (APNS_KEY_PATH)
    let keyData: String
    if let inlineKey = Environment.get("APNS_PRIVATE_KEY") {
        keyData = inlineKey
    } else if let keyPath = Environment.get("APNS_KEY_PATH"),
              let fileData = try? String(contentsOfFile: keyPath, encoding: .utf8) {
        keyData = fileData
    } else {
        app.logger.warning("APNs key not found — set APNS_PRIVATE_KEY (inline) or APNS_KEY_PATH (file). Using mock service.")
        app.apnsServiceCustom = MockAPNsService()
        return
    }

    let privateKey: P256.Signing.PrivateKey
    do {
        privateKey = try P256.Signing.PrivateKey(pemRepresentation: keyData)
    } catch {
        app.logger.error("Failed to parse APNs private key: \(error) — falling back to mock service.")
        app.apnsServiceCustom = MockAPNsService()
        return
    }

    let apnsConfig = APNSClientConfiguration(
        authenticationMethod: APNSClientConfiguration.AuthenticationMethod.jwt(
            privateKey: privateKey,
            keyIdentifier: keyID,
            teamIdentifier: teamID
        ),
        environment: app.environment == .production ? APNSEnvironment.production : APNSEnvironment.sandbox
    )
    app.apns.containers.use(
        apnsConfig,
        eventLoopGroupProvider: .shared(app.eventLoopGroup),
        responseDecoder: JSONDecoder(),
        requestEncoder: JSONEncoder(),
        as: .default
    )
    app.apnsServiceCustom = LiveAPNsService(app: app)
}

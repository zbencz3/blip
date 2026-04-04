import Vapor
import Fluent
import FluentSQLiteDriver
import APNSCore
import VaporAPNS
import APNS
import Crypto

func configure(_ app: Application) async throws {
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateDeviceRegistration())
    try await app.autoMigrate()

    configureAPNs(app)

    try routes(app)
}

private func configureAPNs(_ app: Application) {
    guard let keyID = Environment.get("APNS_KEY_ID"),
          let teamID = Environment.get("APNS_TEAM_ID"),
          let keyPath = Environment.get("APNS_KEY_PATH"),
          let keyData = try? String(contentsOfFile: keyPath, encoding: .utf8)
    else {
        app.logger.warning("APNs not configured — using mock service. Set APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH to enable.")
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

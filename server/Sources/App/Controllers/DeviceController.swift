import Fluent
import Vapor

struct DeviceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let devices = routes.grouped("v1", "devices")
        devices.post("register", use: register)
        devices.get(use: list)
        devices.delete(":deviceID", use: delete)
    }

    @Sendable
    func register(req: Request) async throws -> DeviceResponse {
        let input = try req.content.decode(DeviceRegisterRequest.self)

        guard !input.deviceToken.isEmpty else {
            throw Abort(.unprocessableEntity, reason: "Device token must not be empty.")
        }
        guard input.deviceToken.count <= 200 else {
            throw Abort(.unprocessableEntity, reason: "Device token is too long.")
        }
        guard !input.deviceName.isEmpty else {
            throw Abort(.unprocessableEntity, reason: "Device name must not be empty.")
        }

        let user = try await findOrCreateUser(secret: input.secret, on: req.db)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing after save.")
        }

        if let existing = try await DeviceRegistration.query(on: req.db)
            .filter(\.$deviceToken == input.deviceToken)
            .first()
        {
            existing.deviceName = input.deviceName
            existing.$user.id = userID
            try await existing.save(on: req.db)

            // Clean up stale registrations: same user + same device name but different token
            try await DeviceRegistration.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$deviceName == input.deviceName)
                .filter(\.$deviceToken != input.deviceToken)
                .delete()

            return try DeviceResponse(from: existing)
        }

        // Clean up stale registrations before creating new one
        try await DeviceRegistration.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceName == input.deviceName)
            .delete()

        let device = DeviceRegistration(
            userID: userID,
            deviceToken: input.deviceToken,
            deviceName: input.deviceName,
            deviceSecret: SecretGenerator.generate()
        )
        try await device.save(on: req.db)
        return try DeviceResponse(from: device)
    }

    @Sendable
    func list(req: Request) async throws -> [DeviceResponse] {
        let user = try await requireUser(from: req)
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }
        let devices = try await DeviceRegistration.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
        return try devices.map { try DeviceResponse(from: $0) }
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try await requireUser(from: req)
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }
        guard let deviceID = req.parameters.get("deviceID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid device ID.")
        }
        guard let device = try await DeviceRegistration.query(on: req.db)
            .filter(\.$id == deviceID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Device not found.")
        }
        try await device.delete(on: req.db)
        return .noContent
    }

    private func findOrCreateUser(secret: String, on db: Database) async throws -> User {
        if let existing = try await User.query(on: db)
            .filter(\.$secret == secret)
            .first()
        {
            return existing
        }
        let user = User(secret: secret)
        do {
            try await user.save(on: db)
        } catch {
            // Another request may have created the user concurrently (unique constraint violation).
            // Re-query and return the existing record if present.
            if let existing = try await User.query(on: db)
                .filter(\.$secret == secret)
                .first()
            {
                return existing
            }
            throw error
        }
        return user
    }

    private func requireUser(from req: Request) async throws -> User {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header.")
        }
        guard let user = try await User.query(on: req.db)
            .filter(\.$secret == bearer.token)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid secret.")
        }
        return user
    }
}

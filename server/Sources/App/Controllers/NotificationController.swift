import Fluent
import Vapor

struct NotificationController: RouteCollection {
    let apnsService: APNsServiceProtocol

    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        v1.post("send", use: sendWithBearer)
        v1.post(":secret", use: sendWithSecret)
    }

    @Sendable
    func sendWithBearer(req: Request) async throws -> NotificationResponse {
        guard let bearer = req.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing authorization header.")
        }
        var notification = try parseNotification(from: req)
        notification.message = notification.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if notification.message?.isEmpty == true { notification.message = nil }
        try notification.validate()
        let (user, devices) = try await resolveUserAndDevices(secret: bearer.token, on: req.db)
        let responseID = try await createPendingResponseIfNeeded(notification: notification, user: user, on: req.db)
        let baseURL = Environment.get("BASE_URL") ?? "https://bzap-server.fly.dev"
        let responseURL = responseID.map { "\(baseURL)/v1/responses/\($0)" }
        try await sendToDevices(notification: notification, devices: devices, responseID: responseID, responseURL: responseURL, logger: req.logger)
        return NotificationResponse(message: "Notification sent", responseId: responseID)
    }

    @Sendable
    func sendWithSecret(req: Request) async throws -> NotificationResponse {
        guard let secret = req.parameters.get("secret") else {
            throw Abort(.badRequest, reason: "Missing secret.")
        }
        // Skip non-secret paths that might match this route
        guard secret.hasPrefix("bps_usr_") else {
            throw Abort(.notFound)
        }
        var notification = try parseNotification(from: req)
        notification.message = notification.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if notification.message?.isEmpty == true { notification.message = nil }
        try notification.validate()
        let (user, devices) = try await resolveUserAndDevices(secret: secret, on: req.db)
        let responseID = try await createPendingResponseIfNeeded(notification: notification, user: user, on: req.db)
        let baseURL = Environment.get("BASE_URL") ?? "https://bzap-server.fly.dev"
        let responseURL = responseID.map { "\(baseURL)/v1/responses/\($0)" }
        try await sendToDevices(notification: notification, devices: devices, responseID: responseID, responseURL: responseURL, logger: req.logger)
        return NotificationResponse(message: "Notification sent", responseId: responseID)
    }

    private func parseNotification(from req: Request) throws -> NotificationRequest {
        let contentType = req.headers.contentType
        if contentType == .plainText {
            let body = req.body.string ?? ""
            return NotificationRequest(message: body)
        }
        return try req.content.decode(NotificationRequest.self)
    }

    private func resolveUserAndDevices(secret: String, on db: Database) async throws -> (User, [DeviceRegistration]) {
        // Check device-specific secret first
        if let device = try await DeviceRegistration.query(on: db)
            .filter(\.$deviceSecret == secret)
            .with(\.$user)
            .first()
        {
            return (device.user, [device])
        }

        // Then check user secret
        guard let user = try await User.query(on: db)
            .filter(\.$secret == secret)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid secret.")
        }

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }

        let devices = try await DeviceRegistration.query(on: db)
            .filter(\.$user.$id == userID)
            .all()

        guard !devices.isEmpty else {
            throw Abort(.notFound, reason: "No devices registered.")
        }

        return (user, devices)
    }

    private func createPendingResponseIfNeeded(
        notification: NotificationRequest,
        user: User,
        on db: Database
    ) async throws -> String? {
        let hasResponseChannel = notification.actions?.contains { $0.responseChannel == true } ?? false
        guard hasResponseChannel, let userID = user.id else { return nil }

        let pending = PendingResponse(userID: userID)
        try await pending.save(on: db)
        return pending.id?.uuidString
    }

    private func sendToDevices(
        notification: NotificationRequest,
        devices: [DeviceRegistration],
        responseID: String? = nil,
        responseURL: String? = nil,
        logger: Logger
    ) async throws {
        let payload = NotificationPayload(
            title: notification.title,
            subtitle: notification.subtitle,
            body: notification.message,
            threadId: notification.threadId,
            sound: notification.sound,
            openUrl: notification.openUrl,
            imageUrl: notification.imageUrl,
            expirationDate: notification.expirationDate,
            interruptionLevel: notification.interruptionLevel,
            filterCriteria: notification.filterCriteria,
            actions: notification.actions,
            responseID: responseID,
            responseURL: responseURL
        )

        var errors: [Error] = []
        for device in devices {
            do {
                try await apnsService.send(payload, to: device.deviceToken)
            } catch {
                logger.warning("Failed to send to device \(device.deviceToken): \(error)")
                errors.append(error)
            }
        }

        // Return 200 if at least one send succeeded
        if errors.count == devices.count {
            throw errors.first ?? Abort(.internalServerError, reason: "All sends failed.")
        }
    }
}

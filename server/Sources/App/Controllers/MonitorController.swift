import Fluent
import Vapor

struct MonitorController: RouteCollection {
    static let freeMonitorLimit = 5
    static let premiumMonitorLimit = 50

    func boot(routes: RoutesBuilder) throws {
        let monitors = routes.grouped("v1", "monitors")
        monitors.post(use: create)
        monitors.get(use: list)
        monitors.get(":monitorID", use: get)
        monitors.delete(":monitorID", use: delete)
        monitors.patch(":monitorID", use: update)
    }

    @Sendable
    func create(req: Request) async throws -> MonitorResponse {
        let user = try await requireUser(from: req)
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }

        let input = try req.content.decode(CreateMonitorRequest.self)
        try input.validate()

        let existingCount = try await Monitor.query(on: req.db)
            .filter(\.$user.$id == userID)
            .count()

        // TODO: Check premium status when subscriptions are implemented
        let limit = Self.freeMonitorLimit
        guard existingCount < limit else {
            throw Abort(.forbidden, reason: "Monitor limit reached (\(limit)). Upgrade to add more.")
        }

        let monitor = Monitor(
            userID: userID,
            name: input.name,
            url: input.url,
            interval: input.interval
        )
        try await monitor.save(on: req.db)
        return try MonitorResponse(from: monitor)
    }

    @Sendable
    func list(req: Request) async throws -> [MonitorResponse] {
        let user = try await requireUser(from: req)
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }
        let monitors = try await Monitor.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .ascending)
            .all()
        return try monitors.map { try MonitorResponse(from: $0) }
    }

    @Sendable
    func get(req: Request) async throws -> MonitorResponse {
        let monitor = try await requireMonitor(from: req)
        return try MonitorResponse(from: monitor)
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let monitor = try await requireMonitor(from: req)
        try await monitor.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func update(req: Request) async throws -> MonitorResponse {
        let monitor = try await requireMonitor(from: req)
        let input = try req.content.decode(UpdateMonitorRequest.self)
        try input.validate()

        if let name = input.name { monitor.name = name }
        if let url = input.url {
            monitor.url = url
            monitor.status = "pending"
            monitor.consecutiveFailures = 0
            monitor.lastCheckedAt = nil
            monitor.lastStatusChange = nil
        }
        if let interval = input.interval { monitor.interval = interval }

        try await monitor.save(on: req.db)
        return try MonitorResponse(from: monitor)
    }

    // MARK: - Helpers

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

    private func requireMonitor(from req: Request) async throws -> Monitor {
        let user = try await requireUser(from: req)
        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing.")
        }
        guard let monitorID = req.parameters.get("monitorID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid monitor ID.")
        }
        guard let monitor = try await Monitor.query(on: req.db)
            .filter(\.$id == monitorID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Monitor not found.")
        }
        return monitor
    }
}

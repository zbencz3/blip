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
        monitors.get(":monitorID", "stats", use: stats)
        monitors.get(":monitorID", "incidents", use: incidents)
        monitors.get(":monitorID", "checks", use: checks)
        monitors.post(":monitorID", "pause", use: pause)
        routes.grouped("v1").get("status-token", use: statusToken)
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

        let monitorType = input.type ?? "http"
        let resolvedMethod = monitorType == "heartbeat" ? "HEAD" : input.resolvedMethod

        let monitor = Monitor(
            userID: userID,
            name: input.name,
            url: input.url ?? "",
            interval: input.interval,
            type: monitorType,
            method: resolvedMethod,
            keyword: input.keyword,
            keywordShouldExist: input.keywordShouldExist ?? true,
            failureThreshold: input.failureThreshold ?? 3,
            gracePeriod: input.gracePeriod ?? (monitorType == "heartbeat" ? input.interval : nil)
        )

        if monitorType == "heartbeat" {
            let token = Monitor.generateHeartbeatToken()
            monitor.heartbeatToken = token
            let baseURL = Environment.get("BASE_URL") ?? "https://bzap-server.fly.dev"
            monitor.url = "\(baseURL)/v1/heartbeat/\(token)"
        }

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
        if let url = input.url, monitor.type == "http" {
            monitor.url = url
            monitor.status = "pending"
            monitor.consecutiveFailures = 0
            monitor.lastCheckedAt = nil
            monitor.lastStatusChange = nil
        }
        if let interval = input.interval { monitor.interval = interval }
        if let method = input.method, monitor.type == "http" { monitor.method = method }
        if let keyword = input.keyword {
            monitor.keyword = keyword
            // Auto-switch HEAD to GET when keyword is set
            if monitor.method == "HEAD" { monitor.method = "GET" }
        }
        if let keywordShouldExist = input.keywordShouldExist { monitor.keywordShouldExist = keywordShouldExist }
        if let failureThreshold = input.failureThreshold { monitor.failureThreshold = failureThreshold }
        if let gracePeriod = input.gracePeriod { monitor.gracePeriod = gracePeriod }

        try await monitor.save(on: req.db)
        return try MonitorResponse(from: monitor)
    }

    @Sendable
    func stats(req: Request) async throws -> MonitorStatsResponse {
        let monitor = try await requireMonitor(from: req)
        guard let monitorID = monitor.id else {
            throw Abort(.internalServerError, reason: "Monitor ID missing.")
        }

        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 86400)
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)

        let allChecks = try await MonitorCheck.query(on: req.db)
            .filter(\.$monitor.$id == monitorID)
            .filter(\.$checkedAt >= thirtyDaysAgo)
            .sort(\.$checkedAt, .descending)
            .all()

        let checks7d = allChecks.filter { ($0.checkedAt ?? .distantPast) >= sevenDaysAgo }

        let uptime7d: Double? = checks7d.isEmpty ? nil : {
            let upCount = checks7d.filter { $0.status == "up" }.count
            return (Double(upCount) / Double(checks7d.count)) * 100.0
        }()

        let uptime30d: Double? = allChecks.isEmpty ? nil : {
            let upCount = allChecks.filter { $0.status == "up" }.count
            return (Double(upCount) / Double(allChecks.count)) * 100.0
        }()

        let responseTimes = allChecks.filter { $0.status == "up" }.map(\.responseTimeMs)

        return MonitorStatsResponse(
            uptime7d: uptime7d.map { ($0 * 100).rounded() / 100 },
            uptime30d: uptime30d.map { ($0 * 100).rounded() / 100 },
            avgResponseMs: responseTimes.isEmpty ? nil : responseTimes.reduce(0, +) / responseTimes.count,
            minResponseMs: responseTimes.min(),
            maxResponseMs: responseTimes.max(),
            totalChecks: allChecks.count
        )
    }

    @Sendable
    func incidents(req: Request) async throws -> [MonitorIncidentResponse] {
        let monitor = try await requireMonitor(from: req)
        guard let monitorID = monitor.id else {
            throw Abort(.internalServerError, reason: "Monitor ID missing.")
        }

        // Return checks where status is "down" (incidents), last 50
        let downChecks = try await MonitorCheck.query(on: req.db)
            .filter(\.$monitor.$id == monitorID)
            .filter(\.$status == "down")
            .sort(\.$checkedAt, .descending)
            .range(..<50)
            .all()

        return downChecks.compactMap { check in
            guard let id = check.id else { return nil }
            return MonitorIncidentResponse(
                id: id,
                status: check.status,
                checkedAt: check.checkedAt,
                responseTimeMs: check.responseTimeMs,
                error: check.error
            )
        }
    }

    @Sendable
    func checks(req: Request) async throws -> [MonitorCheckResponse] {
        let monitor = try await requireMonitor(from: req)
        guard let monitorID = monitor.id else {
            throw Abort(.internalServerError, reason: "Monitor ID missing.")
        }

        // Last 100 checks for chart data
        let recentChecks = try await MonitorCheck.query(on: req.db)
            .filter(\.$monitor.$id == monitorID)
            .sort(\.$checkedAt, .descending)
            .range(..<100)
            .all()

        return recentChecks.reversed().map { check in
            MonitorCheckResponse(
                responseTimeMs: check.responseTimeMs,
                status: check.status,
                checkedAt: check.checkedAt
            )
        }
    }

    @Sendable
    func pause(req: Request) async throws -> MonitorResponse {
        let monitor = try await requireMonitor(from: req)
        let input = try req.content.decode(PauseMonitorRequest.self)

        if input.paused {
            monitor.status = "paused"
        } else {
            monitor.status = "pending"
            monitor.consecutiveFailures = 0
            monitor.lastCheckedAt = nil
        }

        try await monitor.save(on: req.db)
        return try MonitorResponse(from: monitor)
    }

    @Sendable
    func statusToken(req: Request) async throws -> [String: String] {
        let user = try await requireUser(from: req)
        if user.statusToken == nil {
            user.statusToken = User.generateStatusToken()
            try await user.save(on: req.db)
        }
        return ["status_token": user.statusToken ?? ""]
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

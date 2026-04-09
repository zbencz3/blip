import Fluent
import Vapor

struct HeartbeatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let heartbeat = routes.grouped("v1", "heartbeat")
        heartbeat.post(":token", use: ping)
        heartbeat.get(":token", use: ping)
    }

    @Sendable
    func ping(req: Request) async throws -> [String: String] {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Missing heartbeat token.")
        }

        guard let monitor = try await Monitor.query(on: req.db)
            .filter(\.$heartbeatToken == token)
            .first()
        else {
            throw Abort(.notFound, reason: "Heartbeat monitor not found.")
        }

        let previousStatus = monitor.status

        monitor.lastCheckedAt = Date()
        monitor.consecutiveFailures = 0

        let wasDown = previousStatus == "down"
        if wasDown || previousStatus == "pending" {
            monitor.status = "up"
            monitor.lastStatusChange = Date()
        }

        try await monitor.save(on: req.db)

        // Save check record
        if let monitorID = monitor.id {
            let check = MonitorCheck(
                monitorID: monitorID,
                statusCode: 0,
                responseTimeMs: 0,
                status: "up"
            )
            try await check.save(on: req.db)
        }

        // Send recovery notification if was down
        if wasDown {
            await sendRecoveryNotification(monitor: monitor, app: req.application)
        }

        return ["status": "ok"]
    }

    private func sendRecoveryNotification(monitor: Monitor, app: Application) async {
        do {
            let userID = monitor.$user.id
            let devices = try await DeviceRegistration.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()

            guard !devices.isEmpty else { return }

            let payload = NotificationPayload(
                title: "\u{1F7E2} \(monitor.name) is back up",
                subtitle: nil,
                body: "Heartbeat received — \(monitor.name) is responding again.",
                threadId: "monitor-\(monitor.id?.uuidString ?? "")",
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

            for device in devices {
                do {
                    try await app.apnsServiceCustom.send(payload, to: device.deviceToken)
                } catch {
                    app.logger.warning("Failed to send heartbeat recovery notification to \(device.deviceToken): \(error)")
                }
            }
        } catch {
            app.logger.error("Failed to send heartbeat recovery notification: \(error)")
        }
    }
}

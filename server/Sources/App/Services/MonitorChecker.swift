import Vapor
import Fluent
import AsyncHTTPClient
import NIOCore

struct MonitorChecker {
    static func checkAll(app: Application) async {
        do {
            let now = Date()
            let monitors = try await Monitor.query(on: app.db)
                .filter(\.$status != "paused")
                .all()

            let dueMonitors = monitors.filter { monitor in
                guard let lastChecked = monitor.lastCheckedAt else { return true }
                return lastChecked.addingTimeInterval(Double(monitor.interval)) <= now
            }

            for monitor in dueMonitors {
                await check(monitor: monitor, app: app)
            }
        } catch {
            app.logger.error("MonitorChecker.checkAll failed: \(error)")
        }
    }

    static func check(monitor: Monitor, app: Application) async {
        let previousStatus = monitor.status
        let start = DispatchTime.now()
        var statusCode: Int = 0
        var errorMessage: String?

        do {
            var request = HTTPClientRequest(url: monitor.url)
            request.method = .HEAD
            let response = try await app.http.client.shared.execute(
                request,
                timeout: .seconds(10)
            )

            statusCode = Int(response.status.code)
            if (200..<300).contains(statusCode) {
                monitor.status = "up"
                monitor.consecutiveFailures = 0
            } else {
                monitor.consecutiveFailures += 1
                errorMessage = "HTTP \(statusCode)"
                if monitor.consecutiveFailures >= 3 {
                    monitor.status = "down"
                }
            }
        } catch {
            app.logger.warning("Monitor check failed for \(monitor.url): \(error)")
            monitor.consecutiveFailures += 1
            errorMessage = String(describing: error).prefix(200).description
            if monitor.consecutiveFailures >= 3 {
                monitor.status = "down"
            }
        }

        let end = DispatchTime.now()
        let responseTimeMs = Int((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

        monitor.lastCheckedAt = Date()

        let statusChanged = previousStatus != monitor.status
        if statusChanged {
            monitor.lastStatusChange = Date()
        }

        do {
            try await monitor.save(on: app.db)
        } catch {
            app.logger.error("Failed to save monitor \(monitor.id?.uuidString ?? "?"): \(error)")
            return
        }

        // Save check history
        if let monitorID = monitor.id {
            let check = MonitorCheck(
                monitorID: monitorID,
                statusCode: statusCode,
                responseTimeMs: responseTimeMs,
                error: errorMessage,
                status: monitor.status == "up" ? "up" : "down"
            )
            do {
                try await check.save(on: app.db)
            } catch {
                app.logger.error("Failed to save monitor check: \(error)")
            }
        }

        // Send notifications on status transitions
        if statusChanged {
            if monitor.status == "down" {
                await sendNotification(
                    title: "🔴 \(monitor.name) is down",
                    body: "\(monitor.url) is not responding.",
                    monitor: monitor,
                    app: app
                )
            } else if monitor.status == "up" && previousStatus == "down" {
                await sendNotification(
                    title: "🟢 \(monitor.name) is back up",
                    body: "\(monitor.url) is responding again.",
                    monitor: monitor,
                    app: app
                )
            }
        }
    }

    private static func sendNotification(
        title: String,
        body: String,
        monitor: Monitor,
        app: Application
    ) async {
        do {
            let userID = monitor.$user.id
            let devices = try await DeviceRegistration.query(on: app.db)
                .filter(\.$user.$id == userID)
                .all()

            guard !devices.isEmpty else { return }

            let payload = NotificationPayload(
                title: title,
                subtitle: nil,
                body: body,
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
                    app.logger.warning("Failed to send monitor notification to \(device.deviceToken): \(error)")
                }
            }
        } catch {
            app.logger.error("Failed to send monitor notification: \(error)")
        }
    }
}

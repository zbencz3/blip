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
                if monitor.type == "heartbeat" {
                    await checkHeartbeat(monitor: monitor, app: app)
                } else {
                    await checkHTTP(monitor: monitor, app: app)
                }
            }
        } catch {
            app.logger.error("MonitorChecker.checkAll failed: \(error)")
        }
    }

    static func checkHTTP(monitor: Monitor, app: Application) async {
        let previousStatus = monitor.status
        let start = DispatchTime.now()
        var statusCode: Int = 0
        var errorMessage: String?
        var keywordMatched: Bool?

        do {
            var request = HTTPClientRequest(url: monitor.url)
            request.method = monitor.method == "GET" ? .GET : .HEAD

            let response = try await app.http.client.shared.execute(
                request,
                timeout: .seconds(10)
            )

            statusCode = Int(response.status.code)
            if (200..<300).contains(statusCode) {
                // Check keyword if configured and using GET
                if let keyword = monitor.keyword, monitor.method == "GET" {
                    let body = try await response.body.collect(upTo: 1_048_576) // 1MB limit
                    let bodyString = String(buffer: body)
                    let found = bodyString.contains(keyword)
                    keywordMatched = found

                    let shouldExist = monitor.keywordShouldExist
                    if (shouldExist && !found) || (!shouldExist && found) {
                        monitor.consecutiveFailures += 1
                        errorMessage = shouldExist
                            ? "Keyword '\(keyword)' not found"
                            : "Keyword '\(keyword)' found (should not exist)"
                        if monitor.consecutiveFailures >= monitor.failureThreshold {
                            monitor.status = "down"
                        }
                    } else {
                        monitor.status = "up"
                        monitor.consecutiveFailures = 0
                    }
                } else {
                    monitor.status = "up"
                    monitor.consecutiveFailures = 0
                }
            } else {
                monitor.consecutiveFailures += 1
                errorMessage = "HTTP \(statusCode)"
                if monitor.consecutiveFailures >= monitor.failureThreshold {
                    monitor.status = "down"
                }
            }
        } catch {
            app.logger.warning("Monitor check failed for \(monitor.url): \(error)")
            monitor.consecutiveFailures += 1
            errorMessage = String(describing: error).prefix(200).description
            if monitor.consecutiveFailures >= monitor.failureThreshold {
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
                status: errorMessage == nil ? "up" : "down",
                keywordMatched: keywordMatched
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
                    title: "\u{1F534} \(monitor.name) is down",
                    body: errorMessage ?? "\(monitor.url) is not responding.",
                    monitor: monitor,
                    app: app
                )
            } else if monitor.status == "up" && previousStatus == "down" {
                await sendNotification(
                    title: "\u{1F7E2} \(monitor.name) is back up",
                    body: "\(monitor.url) is responding again.",
                    monitor: monitor,
                    app: app
                )
            }
        }
    }

    static func checkHeartbeat(monitor: Monitor, app: Application) async {
        let previousStatus = monitor.status
        let now = Date()

        let gracePeriod = monitor.gracePeriod ?? monitor.interval

        // Never-pinged heartbeat: check if creation + interval + grace has passed
        let referenceDate: Date
        if let lastChecked = monitor.lastCheckedAt {
            referenceDate = lastChecked
        } else if let created = monitor.createdAt {
            referenceDate = created
        } else {
            return
        }

        let deadline = referenceDate.addingTimeInterval(Double(monitor.interval + gracePeriod))

        // Not overdue yet
        guard now > deadline else { return }

        // Already marked down, don't re-trigger
        guard monitor.status != "down" else { return }

        monitor.consecutiveFailures += 1
        // Update lastCheckedAt so the next check waits a full interval before re-checking
        monitor.lastCheckedAt = now

        if monitor.consecutiveFailures >= monitor.failureThreshold {
            monitor.status = "down"
            monitor.lastStatusChange = now
        }

        do {
            try await monitor.save(on: app.db)
        } catch {
            app.logger.error("Failed to save heartbeat monitor \(monitor.id?.uuidString ?? "?"): \(error)")
            return
        }

        // Save check record
        if let monitorID = monitor.id {
            let check = MonitorCheck(
                monitorID: monitorID,
                statusCode: 0,
                responseTimeMs: 0,
                error: "Heartbeat overdue",
                status: "down"
            )
            do {
                try await check.save(on: app.db)
            } catch {
                app.logger.error("Failed to save heartbeat check: \(error)")
            }
        }

        // Send notification if just went down
        if monitor.status == "down" && previousStatus != "down" {
            await sendNotification(
                title: "\u{1F534} \(monitor.name) missed heartbeat",
                body: "No heartbeat received within the expected interval.",
                monitor: monitor,
                app: app
            )
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

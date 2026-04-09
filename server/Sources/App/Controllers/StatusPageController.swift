import Vapor
import Fluent

struct StatusPageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("status", ":token", use: statusPage)
    }

    @Sendable
    func statusPage(req: Request) async throws -> Response {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest)
        }

        guard let user = try await User.query(on: req.db)
            .filter(\.$statusToken == token)
            .first()
        else {
            throw Abort(.notFound, reason: "Status page not found.")
        }

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        let monitors = try await Monitor.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$status != "paused")
            .sort(\.$name, .ascending)
            .all()

        // Compute stats per monitor
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 86400)
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)

        var monitorRows = ""
        var allUp = true

        for monitor in monitors {
            guard let monitorID = monitor.id else { continue }

            let checks = try await MonitorCheck.query(on: req.db)
                .filter(\.$monitor.$id == monitorID)
                .filter(\.$checkedAt >= thirtyDaysAgo)
                .all()

            let checks7d = checks.filter { ($0.checkedAt ?? .distantPast) >= sevenDaysAgo }
            let uptime7d: String = checks7d.isEmpty ? "—" : {
                let pct = (Double(checks7d.filter { $0.status == "up" }.count) / Double(checks7d.count)) * 100
                return String(format: "%.1f%%", pct)
            }()

            let responseTimes = checks.filter { $0.status == "up" }.map(\.responseTimeMs)
            let avgMs = responseTimes.isEmpty ? "—" : "\(responseTimes.reduce(0, +) / responseTimes.count)ms"

            let statusDot: String
            let statusText: String
            let statusClass: String
            switch monitor.status {
            case "up":
                statusDot = "●"
                statusText = "UP"
                statusClass = "up"
            case "down":
                statusDot = "●"
                statusText = "DOWN"
                statusClass = "down"
                allUp = false
            default:
                statusDot = "○"
                statusText = "PENDING"
                statusClass = "pending"
            }

            let lastCheck: String
            if let date = monitor.lastCheckedAt {
                let ago = Int(Date().timeIntervalSince(date))
                if ago < 60 {
                    lastCheck = "\(ago)s ago"
                } else if ago < 3600 {
                    lastCheck = "\(ago / 60)m ago"
                } else {
                    lastCheck = "\(ago / 3600)h ago"
                }
            } else {
                lastCheck = "never"
            }

            monitorRows += """
            <div class="monitor">
                <div class="monitor-header">
                    <span class="dot \(statusClass)">\(statusDot)</span>
                    <span class="name">\(escapeHTML(monitor.name))</span>
                    <span class="status \(statusClass)">\(statusText)</span>
                </div>
                <div class="monitor-meta">
                    <span>uptime: \(uptime7d)</span>
                    <span>avg: \(avgMs)</span>
                    <span>checked: \(lastCheck)</span>
                </div>
            </div>
            """
        }

        let overallStatus = monitors.isEmpty ? "NO MONITORS" : (allUp ? "ALL SYSTEMS OPERATIONAL" : "DEGRADED")
        let overallClass = monitors.isEmpty ? "pending" : (allUp ? "up" : "down")

        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Status — Bzap</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: #0a0a0a;
                    color: #e0e0e0;
                    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
                    padding: 24px;
                    max-width: 640px;
                    margin: 0 auto;
                }
                .header {
                    text-align: center;
                    margin-bottom: 32px;
                    padding-bottom: 24px;
                    border-bottom: 1px solid #1a1a2e;
                }
                .header h1 {
                    font-size: 13px;
                    color: #666;
                    font-weight: 500;
                    letter-spacing: 2px;
                    text-transform: uppercase;
                }
                .overall {
                    text-align: center;
                    margin-bottom: 32px;
                }
                .overall .badge {
                    display: inline-block;
                    padding: 8px 20px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 700;
                    letter-spacing: 1px;
                }
                .overall .badge.up { background: rgba(0,255,0,0.1); color: #00ff00; border: 1px solid rgba(0,255,0,0.2); }
                .overall .badge.down { background: rgba(255,0,0,0.1); color: #ff4444; border: 1px solid rgba(255,0,0,0.2); }
                .overall .badge.pending { background: rgba(255,165,0,0.1); color: #ffa500; border: 1px solid rgba(255,165,0,0.2); }
                .monitor {
                    background: #111;
                    border: 1px solid #1a1a2e;
                    border-radius: 8px;
                    padding: 16px;
                    margin-bottom: 8px;
                }
                .monitor-header {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                    margin-bottom: 8px;
                }
                .dot { font-size: 10px; }
                .dot.up { color: #00ff00; }
                .dot.down { color: #ff4444; }
                .dot.pending { color: #ffa500; }
                .name { flex: 1; font-size: 14px; font-weight: 600; }
                .status {
                    font-size: 10px;
                    font-weight: 700;
                    padding: 3px 8px;
                    border-radius: 10px;
                    letter-spacing: 1px;
                }
                .status.up { background: rgba(0,255,0,0.1); color: #00ff00; }
                .status.down { background: rgba(255,0,0,0.1); color: #ff4444; }
                .status.pending { background: rgba(255,165,0,0.1); color: #ffa500; }
                .monitor-meta {
                    display: flex;
                    gap: 16px;
                    font-size: 11px;
                    color: #555;
                }
                .footer {
                    text-align: center;
                    margin-top: 32px;
                    padding-top: 24px;
                    border-top: 1px solid #1a1a2e;
                    font-size: 11px;
                    color: #333;
                }
                .footer a { color: #7c3aed; text-decoration: none; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>⚡ System Status</h1>
            </div>
            <div class="overall">
                <span class="badge \(overallClass)">\(overallStatus)</span>
            </div>
            \(monitorRows)
            <div class="footer">
                Powered by <a href="https://zbencz3.github.io/blip/">Bzap</a>
            </div>
        </body>
        </html>
        """

        return Response(
            status: .ok,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: .init(string: html)
        )
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

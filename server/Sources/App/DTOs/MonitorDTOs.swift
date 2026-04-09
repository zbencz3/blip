import Vapor

struct CreateMonitorRequest: Content {
    let name: String
    let url: String
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case name, url, interval
    }

    func validate() throws {
        guard !name.isEmpty else {
            throw Abort(.unprocessableEntity, reason: "Name must not be empty.")
        }
        guard name.count <= 100 else {
            throw Abort(.unprocessableEntity, reason: "Name must be 100 characters or fewer.")
        }
        guard url.hasPrefix("https://") || url.hasPrefix("http://") else {
            throw Abort(.unprocessableEntity, reason: "URL must start with 'https://' or 'http://'.")
        }
        guard url.count <= 2048 else {
            throw Abort(.unprocessableEntity, reason: "URL must be 2048 characters or fewer.")
        }
        guard [60, 300, 900].contains(interval) else {
            throw Abort(.unprocessableEntity, reason: "Interval must be 60, 300, or 900 seconds.")
        }
    }
}

struct UpdateMonitorRequest: Content {
    let name: String?
    let url: String?
    let interval: Int?

    func validate() throws {
        if let name {
            guard !name.isEmpty else {
                throw Abort(.unprocessableEntity, reason: "Name must not be empty.")
            }
            guard name.count <= 100 else {
                throw Abort(.unprocessableEntity, reason: "Name must be 100 characters or fewer.")
            }
        }
        if let url {
            guard url.hasPrefix("https://") || url.hasPrefix("http://") else {
                throw Abort(.unprocessableEntity, reason: "URL must start with 'https://' or 'http://'.")
            }
            guard url.count <= 2048 else {
                throw Abort(.unprocessableEntity, reason: "URL must be 2048 characters or fewer.")
            }
        }
        if let interval {
            guard [60, 300, 900].contains(interval) else {
                throw Abort(.unprocessableEntity, reason: "Interval must be 60, 300, or 900 seconds.")
            }
        }
    }
}

struct MonitorResponse: Content {
    let id: UUID
    let name: String
    let url: String
    let interval: Int
    let status: String
    let lastCheckedAt: Date?
    let lastStatusChange: Date?
    let consecutiveFailures: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, url, interval, status
        case lastCheckedAt = "last_checked_at"
        case lastStatusChange = "last_status_change"
        case consecutiveFailures = "consecutive_failures"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from monitor: Monitor) throws {
        guard let id = monitor.id else {
            throw Abort(.internalServerError, reason: "Monitor ID missing.")
        }
        self.id = id
        self.name = monitor.name
        self.url = monitor.url
        self.interval = monitor.interval
        self.status = monitor.status
        self.lastCheckedAt = monitor.lastCheckedAt
        self.lastStatusChange = monitor.lastStatusChange
        self.consecutiveFailures = monitor.consecutiveFailures
        self.createdAt = monitor.createdAt
        self.updatedAt = monitor.updatedAt
    }
}

struct MonitorStatusResponse: Content {
    let id: UUID
    let status: String
    let lastCheckedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case lastCheckedAt = "last_checked_at"
    }

    init(from monitor: Monitor) throws {
        guard let id = monitor.id else {
            throw Abort(.internalServerError, reason: "Monitor ID missing.")
        }
        self.id = id
        self.status = monitor.status
        self.lastCheckedAt = monitor.lastCheckedAt
    }
}

struct MonitorStatsResponse: Content {
    let uptime7d: Double?
    let uptime30d: Double?
    let avgResponseMs: Int?
    let minResponseMs: Int?
    let maxResponseMs: Int?
    let totalChecks: Int

    enum CodingKeys: String, CodingKey {
        case uptime7d = "uptime_7d"
        case uptime30d = "uptime_30d"
        case avgResponseMs = "avg_response_ms"
        case minResponseMs = "min_response_ms"
        case maxResponseMs = "max_response_ms"
        case totalChecks = "total_checks"
    }
}

struct MonitorIncidentResponse: Content {
    let id: UUID
    let status: String
    let checkedAt: Date?
    let responseTimeMs: Int
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, status, error
        case checkedAt = "checked_at"
        case responseTimeMs = "response_time_ms"
    }
}

struct MonitorCheckResponse: Content {
    let responseTimeMs: Int
    let status: String
    let checkedAt: Date?

    enum CodingKeys: String, CodingKey {
        case responseTimeMs = "response_time_ms"
        case status
        case checkedAt = "checked_at"
    }
}

struct PauseMonitorRequest: Content {
    let paused: Bool
}

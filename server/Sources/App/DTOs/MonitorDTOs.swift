import Vapor

struct CreateMonitorRequest: Content {
    let name: String
    let url: String?
    let interval: Int
    let type: String?
    let method: String?
    let keyword: String?
    let keywordShouldExist: Bool?
    let failureThreshold: Int?
    let gracePeriod: Int?

    enum CodingKeys: String, CodingKey {
        case name, url, interval, type, method, keyword
        case keywordShouldExist = "keyword_should_exist"
        case failureThreshold = "failure_threshold"
        case gracePeriod = "grace_period"
    }

    init(
        name: String,
        url: String? = nil,
        interval: Int,
        type: String? = nil,
        method: String? = nil,
        keyword: String? = nil,
        keywordShouldExist: Bool? = nil,
        failureThreshold: Int? = nil,
        gracePeriod: Int? = nil
    ) {
        self.name = name
        self.url = url
        self.interval = interval
        self.type = type
        self.method = method
        self.keyword = keyword
        self.keywordShouldExist = keywordShouldExist
        self.failureThreshold = failureThreshold
        self.gracePeriod = gracePeriod
    }

    func validate() throws {
        guard !name.isEmpty else {
            throw Abort(.unprocessableEntity, reason: "Name must not be empty.")
        }
        guard name.count <= 100 else {
            throw Abort(.unprocessableEntity, reason: "Name must be 100 characters or fewer.")
        }

        let monitorType = type ?? "http"
        guard ["http", "heartbeat"].contains(monitorType) else {
            throw Abort(.unprocessableEntity, reason: "Type must be 'http' or 'heartbeat'.")
        }

        if monitorType == "http" {
            guard let url else {
                throw Abort(.unprocessableEntity, reason: "URL is required for HTTP monitors.")
            }
            guard url.hasPrefix("https://") || url.hasPrefix("http://") else {
                throw Abort(.unprocessableEntity, reason: "URL must start with 'https://' or 'http://'.")
            }
            guard url.count <= 2048 else {
                throw Abort(.unprocessableEntity, reason: "URL must be 2048 characters or fewer.")
            }
        }

        if let method {
            guard ["HEAD", "GET"].contains(method) else {
                throw Abort(.unprocessableEntity, reason: "Method must be 'HEAD' or 'GET'.")
            }
        }

        guard [60, 300, 900].contains(interval) else {
            throw Abort(.unprocessableEntity, reason: "Interval must be 60, 300, or 900 seconds.")
        }

        if let failureThreshold {
            guard (1...10).contains(failureThreshold) else {
                throw Abort(.unprocessableEntity, reason: "Failure threshold must be between 1 and 10.")
            }
        }

        if let gracePeriod {
            guard (0...3600).contains(gracePeriod) else {
                throw Abort(.unprocessableEntity, reason: "Grace period must be between 0 and 3600 seconds.")
            }
        }
    }

    /// Resolved method: auto-switch HEAD to GET when keyword is set.
    var resolvedMethod: String {
        if keyword != nil && (method == nil || method == "HEAD") {
            return "GET"
        }
        return method ?? "HEAD"
    }
}

struct UpdateMonitorRequest: Content {
    let name: String?
    let url: String?
    let interval: Int?
    let method: String?
    let keyword: String?
    let keywordShouldExist: Bool?
    let failureThreshold: Int?
    let gracePeriod: Int?

    enum CodingKeys: String, CodingKey {
        case name, url, interval, method, keyword
        case keywordShouldExist = "keyword_should_exist"
        case failureThreshold = "failure_threshold"
        case gracePeriod = "grace_period"
    }

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
        if let method {
            guard ["HEAD", "GET"].contains(method) else {
                throw Abort(.unprocessableEntity, reason: "Method must be 'HEAD' or 'GET'.")
            }
        }
        if let failureThreshold {
            guard (1...10).contains(failureThreshold) else {
                throw Abort(.unprocessableEntity, reason: "Failure threshold must be between 1 and 10.")
            }
        }
        if let gracePeriod {
            guard (0...3600).contains(gracePeriod) else {
                throw Abort(.unprocessableEntity, reason: "Grace period must be between 0 and 3600 seconds.")
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
    let type: String
    let method: String
    let keyword: String?
    let keywordShouldExist: Bool
    let failureThreshold: Int
    let gracePeriod: Int?
    let heartbeatToken: String?
    let heartbeatUrl: String?
    let sslAlertDays: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, url, interval, status, type, method, keyword
        case lastCheckedAt = "last_checked_at"
        case lastStatusChange = "last_status_change"
        case consecutiveFailures = "consecutive_failures"
        case keywordShouldExist = "keyword_should_exist"
        case failureThreshold = "failure_threshold"
        case gracePeriod = "grace_period"
        case heartbeatToken = "heartbeat_token"
        case heartbeatUrl = "heartbeat_url"
        case sslAlertDays = "ssl_alert_days"
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
        self.type = monitor.type
        self.method = monitor.method
        self.keyword = monitor.keyword
        self.keywordShouldExist = monitor.keywordShouldExist
        self.failureThreshold = monitor.failureThreshold
        self.gracePeriod = monitor.gracePeriod
        self.heartbeatToken = monitor.heartbeatToken
        self.sslAlertDays = monitor.sslAlertDays
        self.createdAt = monitor.createdAt
        self.updatedAt = monitor.updatedAt

        if monitor.type == "heartbeat", let token = monitor.heartbeatToken {
            let baseURL = Environment.get("BASE_URL") ?? "https://bzap-server.fly.dev"
            self.heartbeatUrl = "\(baseURL)/v1/heartbeat/\(token)"
        } else {
            self.heartbeatUrl = nil
        }
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

import Foundation

struct APIClient {
    let baseURL: String

    init(baseURL: String = Constants.apiBaseURL) {
        self.baseURL = baseURL
    }

    // MARK: - Device Registration

    struct RegisterResponse: Codable {
        let id: UUID
        let deviceToken: String
        let deviceName: String
        let deviceSecret: String?

        enum CodingKeys: String, CodingKey {
            case id
            case deviceToken = "device_token"
            case deviceName = "device_name"
            case deviceSecret = "device_secret"
        }
    }

    func registerDevice(secret: String, deviceToken: String, deviceName: String) async throws -> RegisterResponse {
        var request = makeRequest(path: "devices/register", method: "POST")
        request.httpBody = try JSONEncoder().encode([
            "secret": secret,
            "device_token": deviceToken,
            "device_name": deviceName
        ])
        return try await perform(request)
    }

    // MARK: - Device List

    func listDevices(secret: String) async throws -> [Device] {
        var request = makeRequest(path: "devices", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    // MARK: - Delete Device

    func deleteDevice(secret: String, deviceId: UUID) async throws {
        var request = makeRequest(path: "devices/\(deviceId)", method: "DELETE")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    // MARK: - Secret Rotation

    struct RotateResponse: Codable {
        let secret: String
        let webhookUrl: String

        enum CodingKeys: String, CodingKey {
            case secret
            case webhookUrl = "webhook_url"
        }
    }

    func rotateSecret(currentSecret: String) async throws -> RotateResponse {
        var request = makeRequest(path: "secret/rotate", method: "POST")
        request.setValue("Bearer \(currentSecret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    // MARK: - Send Test

    func sendTest(secret: String) async throws {
        let payload: [String: Any] = ["title": "Bzap", "message": "Test notification 🔔"]
        try await sendPayload(payload, secret: secret)
    }

    func sendTestWithActions(secret: String) async throws {
        let payload: [String: Any] = [
            "title": "Deploy Ready",
            "message": "v2.3.1 — all tests passing ✅",
            "actions": [
                ["id": "approve", "label": "Deploy to Prod", "webhook": "https://httpbin.org/post"],
                ["id": "reject", "label": "Rollback", "webhook": "https://httpbin.org/post"]
            ]
        ]
        try await sendPayload(payload, secret: secret)
    }

    func sendTestWithResponseChannel(secret: String) async throws {
        let payload: [String: Any] = [
            "title": "Feedback Request",
            "message": "How's the new build working?",
            "response_url": "https://httpbin.org/post",
            "actions": [
                [
                    "id": "reply",
                    "label": "Reply",
                    "type": "text_input",
                    "text_input_placeholder": "Type your feedback...",
                    "response_channel": true
                ],
                [
                    "id": "thumbsup",
                    "label": "👍 Looks Good",
                    "response_channel": true
                ]
            ]
        ]
        try await sendPayload(payload, secret: secret)
    }

    func sendStatusPagePush(secret: String, statusPageURL: String) async throws {
        let payload: [String: Any] = [
            "title": "Status Page",
            "message": "Tap to view your status page",
            "open_url": statusPageURL
        ]
        try await sendPayload(payload, secret: secret)
    }

    private func sendPayload(_ payload: [String: Any], secret: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(secret)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(path)")!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Monitors

    struct MonitorResponse: Codable, Identifiable {
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
        let createdAt: Date

        var isHeartbeat: Bool { type == "heartbeat" }

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
        }
    }

    func listMonitors(secret: String) async throws -> [MonitorResponse] {
        var request = makeRequest(path: "monitors", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private struct CreateMonitorBody: Encodable {
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
    }

    struct CreateMonitorParams {
        let name: String
        let url: String?
        let interval: Int
        var type: String = "http"
        var method: String = "HEAD"
        var keyword: String?
        var keywordShouldExist: Bool = true
        var failureThreshold: Int = 3
        var gracePeriod: Int?
    }

    func createMonitor(secret: String, params: CreateMonitorParams) async throws -> MonitorResponse {
        var request = makeRequest(path: "monitors", method: "POST")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(CreateMonitorBody(
            name: params.name,
            url: params.url,
            interval: params.interval,
            type: params.type,
            method: params.method,
            keyword: params.keyword?.isEmpty == true ? nil : params.keyword,
            keywordShouldExist: params.keyword != nil ? params.keywordShouldExist : nil,
            failureThreshold: params.failureThreshold,
            gracePeriod: params.gracePeriod
        ))
        return try await perform(request)
    }

    func deleteMonitor(secret: String, monitorId: UUID) async throws {
        var request = makeRequest(path: "monitors/\(monitorId)", method: "DELETE")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    private struct UpdateMonitorBody: Encodable {
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
    }

    func updateMonitor(secret: String, monitorId: UUID, params: CreateMonitorParams) async throws -> MonitorResponse {
        var request = makeRequest(path: "monitors/\(monitorId)", method: "PATCH")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(UpdateMonitorBody(
            name: params.name,
            url: params.type == "http" ? params.url : nil,
            interval: params.interval,
            method: params.type == "http" ? params.method : nil,
            keyword: params.keyword?.isEmpty == true ? nil : params.keyword,
            keywordShouldExist: params.keyword != nil ? params.keywordShouldExist : nil,
            failureThreshold: params.failureThreshold,
            gracePeriod: params.gracePeriod
        ))
        return try await perform(request)
    }

    // MARK: - Monitor Stats

    struct MonitorStatsResponse: Codable {
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

    struct MonitorIncidentResponse: Codable, Identifiable {
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

    struct MonitorCheckResponse: Codable, Identifiable {
        var id: String { "\(checkedAt?.timeIntervalSince1970 ?? 0)-\(responseTimeMs)" }
        let responseTimeMs: Int
        let status: String
        let checkedAt: Date?

        enum CodingKeys: String, CodingKey {
            case responseTimeMs = "response_time_ms"
            case status
            case checkedAt = "checked_at"
        }
    }

    func monitorStats(secret: String, monitorId: UUID) async throws -> MonitorStatsResponse {
        var request = makeRequest(path: "monitors/\(monitorId)/stats", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func monitorIncidents(secret: String, monitorId: UUID) async throws -> [MonitorIncidentResponse] {
        var request = makeRequest(path: "monitors/\(monitorId)/incidents", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func monitorChecks(secret: String, monitorId: UUID) async throws -> [MonitorCheckResponse] {
        var request = makeRequest(path: "monitors/\(monitorId)/checks", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func pauseMonitor(secret: String, monitorId: UUID, paused: Bool) async throws -> MonitorResponse {
        var request = makeRequest(path: "monitors/\(monitorId)/pause", method: "POST")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["paused": paused])
        return try await perform(request)
    }

    // MARK: - Status Token

    func statusToken(secret: String) async throws -> String {
        var request = makeRequest(path: "status-token", method: "GET")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        let response: [String: String] = try await perform(request)
        return response["status_token"] ?? ""
    }
}

enum APIError: Error, LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Request failed"
        }
    }
}

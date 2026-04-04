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
        var request = URLRequest(url: URL(string: "\(baseURL)/\(secret)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["title": "Blip", "message": "Test notification 🔔"])
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
}

enum APIError: Error, LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Request failed"
        }
    }
}

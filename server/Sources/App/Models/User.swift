import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "secret") var secret: String
    @OptionalField(key: "status_token") var statusToken: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @Children(for: \.$user) var devices: [DeviceRegistration]

    init() {}

    init(id: UUID? = nil, secret: String) {
        self.id = id
        self.secret = secret
        self.statusToken = Self.generateStatusToken()
    }

    static func generateStatusToken() -> String {
        let bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return "bps_st_" + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

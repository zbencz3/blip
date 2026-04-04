import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "secret") var secret: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @Children(for: \.$user) var devices: [DeviceRegistration]

    init() {}

    init(id: UUID? = nil, secret: String) {
        self.id = id
        self.secret = secret
    }
}

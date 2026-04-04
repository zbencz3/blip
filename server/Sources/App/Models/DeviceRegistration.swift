import Fluent
import Vapor

final class DeviceRegistration: Model, Content, @unchecked Sendable {
    static let schema = "device_registrations"

    @ID(key: .id) var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "device_token") var deviceToken: String
    @Field(key: "device_name") var deviceName: String
    @OptionalField(key: "device_secret") var deviceSecret: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, deviceToken: String, deviceName: String, deviceSecret: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.deviceToken = deviceToken
        self.deviceName = deviceName
        self.deviceSecret = deviceSecret
    }
}

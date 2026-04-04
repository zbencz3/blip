import Vapor

struct DeviceResponse: Content {
    let id: UUID
    let deviceToken: String
    let deviceName: String
    let deviceSecret: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceToken = "device_token"
        case deviceName = "device_name"
        case deviceSecret = "device_secret"
        case createdAt = "created_at"
    }

    init(from registration: DeviceRegistration) throws {
        guard let id = registration.id else {
            throw Abort(.internalServerError, reason: "Device ID missing after save.")
        }
        self.id = id
        self.deviceToken = registration.deviceToken
        self.deviceName = registration.deviceName
        self.deviceSecret = registration.deviceSecret
        self.createdAt = registration.createdAt
    }
}

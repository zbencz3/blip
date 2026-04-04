import Vapor

struct DeviceRegisterRequest: Content {
    let secret: String
    let deviceToken: String
    let deviceName: String

    enum CodingKeys: String, CodingKey {
        case secret
        case deviceToken = "device_token"
        case deviceName = "device_name"
    }
}

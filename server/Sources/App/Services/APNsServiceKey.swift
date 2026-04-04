import Vapor

struct APNsServiceKey: StorageKey {
    typealias Value = APNsServiceProtocol
}

extension Application {
    var apnsServiceCustom: APNsServiceProtocol {
        get {
            guard let service = storage[APNsServiceKey.self] else {
                fatalError("APNs service not configured")
            }
            return service
        }
        set { storage[APNsServiceKey.self] = newValue }
    }
}

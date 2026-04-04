import Vapor

struct NotificationPayload: Sendable {
    let title: String?
    let subtitle: String?
    let body: String?
    let threadId: String?
    let sound: String?
    let openUrl: String?
    let imageUrl: String?
    let expirationDate: String?
    let interruptionLevel: String?
    let filterCriteria: String?
    let actions: [NotificationAction]?
}

protocol APNsServiceProtocol: Sendable {
    func send(_ payload: NotificationPayload, to deviceToken: String) async throws
}

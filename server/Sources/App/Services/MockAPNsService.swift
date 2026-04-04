import Vapor
import NIOConcurrencyHelpers

final class MockAPNsService: APNsServiceProtocol, @unchecked Sendable {
    struct SentNotification: Sendable {
        let payload: NotificationPayload
        let deviceToken: String
    }

    private let lock = NIOLock()
    private var _sent: [SentNotification] = []

    var sent: [SentNotification] {
        lock.withLock { _sent }
    }

    func send(_ payload: NotificationPayload, to deviceToken: String) async throws {
        lock.withLock {
            _sent.append(SentNotification(payload: payload, deviceToken: deviceToken))
        }
    }

    func reset() {
        lock.withLock { _sent = [] }
    }
}

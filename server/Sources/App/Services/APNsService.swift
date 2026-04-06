import Vapor
import VaporAPNS
import APNSCore

struct LiveAPNsService: APNsServiceProtocol {
    let app: Application

    func send(_ payload: NotificationPayload, to deviceToken: String) async throws {
        let sound: APNSAlertNotificationSound? = if let s = payload.sound {
            s == "default" ? .default : .fileName(s)
        } else {
            nil
        }

        let interruptionLevel = mapInterruptionLevel(payload.interruptionLevel)

        let expiration: APNSNotificationExpiration
        if let dateString = payload.expirationDate,
           let date = ISO8601DateFormatter().date(from: dateString) {
            expiration = .timeIntervalSince1970InSeconds(Int(date.timeIntervalSince1970))
        } else {
            expiration = .none
        }

        let category: String
        let blipActions: [BlipAction]?
        if let actions = payload.actions, !actions.isEmpty {
            // Deterministic category ID based on sorted action IDs
            let actionIds = actions.map(\.id).sorted().joined(separator: "_")
            let hash = actionIds.djb2Hash
            category = "BZAP_DYN_\(hash)"
            blipActions = actions.map { BlipAction(id: $0.id, label: $0.label, webhook: $0.webhook, destructive: $0.destructive) }
        } else {
            category = payload.openUrl != nil ? "BZAP_WITH_URL" : "BZAP_GENERAL"
            blipActions = nil
        }

        let alert = APNSAlertNotification(
            alert: .init(
                title: payload.title.map { .raw($0) },
                subtitle: payload.subtitle.map { .raw($0) },
                body: payload.body.map { .raw($0) }
            ),
            expiration: expiration,
            priority: .immediately,
            topic: Environment.get("APNS_TOPIC") ?? "com.isylva.boopsy",
            payload: BlipPayload(
                openUrl: payload.openUrl,
                imageUrl: payload.imageUrl,
                filterCriteria: payload.filterCriteria,
                actions: blipActions
            ),
            sound: sound,
            threadID: payload.threadId,
            category: category,
            mutableContent: blipActions != nil ? 1.0 : nil,
            interruptionLevel: interruptionLevel
        )

        try await app.apns.client(.default).sendAlertNotification(
            alert,
            deviceToken: deviceToken
        )
    }

    private func mapInterruptionLevel(_ level: String?) -> APNSAlertNotificationInterruptionLevel {
        switch level {
        case "passive": return .passive
        case "time-sensitive": return .timeSensitive
        default: return .active
        }
    }
}

struct BlipPayload: Codable, Sendable {
    let openUrl: String?
    let imageUrl: String?
    let filterCriteria: String?
    let actions: [BlipAction]?

    enum CodingKeys: String, CodingKey {
        case openUrl = "open_url"
        case imageUrl = "image_url"
        case filterCriteria = "filter_criteria"
        case actions
    }
}

struct BlipAction: Codable, Sendable {
    let id: String
    let label: String
    let webhook: String?
    let destructive: Bool?
}

extension String {
    /// Simple DJB2 hash returning a hex string, used for deterministic category IDs.
    var djb2Hash: String {
        var hash: UInt64 = 5381
        for byte in self.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

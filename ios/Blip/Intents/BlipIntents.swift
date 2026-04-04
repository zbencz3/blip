import AppIntents
import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Helpers

enum IntentError: Error, LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Bzap is not configured. Please open the app first."
        }
    }
}

private func currentSecret() throws -> String {
    let keychain = KeychainService()
    guard let secret = keychain.load(key: Constants.Keychain.secretKey) else {
        throw IntentError.notConfigured
    }
    return secret
}

private func currentWebhookURL() throws -> String {
    "\(Constants.apiBaseURL)/\(try currentSecret())"
}

// MARK: - SendNotificationIntent

struct SendNotificationIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Send Bzap Notification"
    nonisolated(unsafe) static var description: IntentDescription = IntentDescription(
        "Send a push notification to your devices via Bzap.",
        categoryName: "Notifications"
    )

    @Parameter(title: "Title")
    var notificationTitle: String?

    @Parameter(title: "Message")
    var message: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let secret = try currentSecret()
        var request = URLRequest(url: URL(string: "\(Constants.apiBaseURL)/\(secret)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["message": message]
        body["title"] = (notificationTitle?.isEmpty == false) ? notificationTitle! : "Bzap"
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
        return .result(value: "Notification sent")
    }
}

// MARK: - CopyWebhookIntent

struct CopyWebhookIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Copy Bzap Webhook URL"
    nonisolated(unsafe) static var description: IntentDescription = IntentDescription(
        "Copy your Bzap webhook URL to the clipboard.",
        categoryName: "Webhooks"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let url = try currentWebhookURL()
        #if canImport(UIKit)
        UIPasteboard.general.string = url
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        #endif
        return .result(value: url)
    }
}

// MARK: - GetWebhookURLIntent

struct GetWebhookURLIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Get Bzap Webhook URL"
    nonisolated(unsafe) static var description: IntentDescription = IntentDescription(
        "Returns your Bzap webhook URL so you can use it in other actions.",
        categoryName: "Webhooks"
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: try currentWebhookURL())
    }
}

// MARK: - AppShortcutsProvider

struct BlipShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendNotificationIntent(),
            phrases: [
                "Send a notification with \(.applicationName)",
                "Send a \(.applicationName) notification"
            ],
            shortTitle: "Send Notification",
            systemImageName: "paperplane.fill"
        )
        AppShortcut(
            intent: CopyWebhookIntent(),
            phrases: [
                "Copy \(.applicationName) webhook",
                "Copy my \(.applicationName) webhook URL"
            ],
            shortTitle: "Copy Webhook",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: GetWebhookURLIntent(),
            phrases: [
                "Get my \(.applicationName) webhook URL",
                "What is my \(.applicationName) webhook"
            ],
            shortTitle: "Get Webhook URL",
            systemImageName: "link"
        )
    }
}

import Foundation
@preconcurrency import UserNotifications

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    var onNotificationReceived: ((UNNotification) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        registerDynamicCategoryIfNeeded(from: notification.request.content)
        onNotificationReceived?(notification)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // Save to history (covers background/killed state notifications)
        onNotificationReceived?(response.notification)

        switch actionIdentifier {
        case "COPY_MESSAGE":
            let body = response.notification.request.content.body
            DispatchQueue.main.async {
                #if canImport(UIKit)
                UIPasteboard.general.string = body
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(body, forType: .string)
                #endif
            }
            completionHandler()

        case "OPEN_URL":
            if let urlString = userInfo["open_url"] as? String,
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }
            completionHandler()

        case "MARK_READ":
            completionHandler()

        default:
            // Check dynamic action webhooks and response channels
            if let actionsData = userInfo["actions"] as? [[String: Any]],
               let actionDict = actionsData.first(where: { ($0["id"] as? String) == actionIdentifier }) {
                // Extract values before Task to avoid capturing non-Sendable types
                let webhookURL = actionDict["webhook"] as? String
                let hasResponseChannel = actionDict["response_channel"] as? Bool == true
                let responseURL = userInfo["response_url"] as? String
                let userText = (response as? UNTextInputNotificationResponse)?.userText
                nonisolated(unsafe) let handler = completionHandler
                Task { @Sendable in
                    #if canImport(UIKit)
                    let deviceName = await MainActor.run { UIDevice.current.name }
                    #else
                    let deviceName = Host.current().localizedName ?? "Mac"
                    #endif

                    // Fire legacy webhook if present (backward compatible)
                    if let webhookURL {
                        await ActionWebhookService.fire(url: webhookURL)
                    }

                    // Submit response channel if enabled
                    if hasResponseChannel, let responseURL {
                        await ResponseSubmitter.submit(
                            url: responseURL,
                            actionID: actionIdentifier,
                            text: userText,
                            deviceName: deviceName
                        )
                    }

                    DispatchQueue.main.async { handler() }
                }
                return
            } else if let urlString = userInfo["open_url"] as? String,
                      let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
                completionHandler()
            } else {
                completionHandler()
            }
        }
    }

    // MARK: - Dynamic Categories

    private func registerDynamicCategoryIfNeeded(from content: UNNotificationContent) {
        guard let actionsData = content.userInfo["actions"] as? [[String: Any]] else { return }

        let actions: [NotificationAction] = actionsData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let label = dict["label"] as? String else { return nil }
            return NotificationAction(
                id: id,
                label: label,
                webhook: dict["webhook"] as? String,
                destructive: dict["destructive"] as? Bool,
                responseChannel: dict["response_channel"] as? Bool,
                type: dict["type"] as? String,
                textInputPlaceholder: dict["text_input_placeholder"] as? String
            )
        }

        guard !actions.isEmpty else { return }

        let categoryId = content.categoryIdentifier
        guard categoryId.hasPrefix("BZAP_DYN_") else { return }

        NotificationCategories.registerDynamic(actions: actions, categoryId: categoryId)
    }
}

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    var onNotificationReceived: ((UNNotification) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Register dynamic category if the notification includes actions
        registerDynamicCategoryIfNeeded(from: notification.request.content)
        onNotificationReceived?(notification)
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "COPY_MESSAGE":
            let body = response.notification.request.content.body
            await MainActor.run {
                #if canImport(UIKit)
                UIPasteboard.general.string = body
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(body, forType: .string)
                #endif
            }

        case "OPEN_URL":
            if let urlString = userInfo["open_url"] as? String,
               let url = URL(string: urlString) {
                await MainActor.run {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }

        case "MARK_READ":
            // No-op — acknowledges the notification
            break

        default:
            // Check if this is a dynamic action with a webhook
            if let handled = await handleDynamicAction(
                actionIdentifier: actionIdentifier,
                userInfo: userInfo
            ), handled {
                break
            }

            // Default tap: open URL if present
            if let urlString = userInfo["open_url"] as? String,
               let url = URL(string: urlString) {
                await MainActor.run {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }
        }
    }

    // MARK: - Dynamic Actions

    private func registerDynamicCategoryIfNeeded(from content: UNNotificationContent) {
        guard let actionsData = content.userInfo["actions"] as? [[String: Any]] else { return }

        let actions: [NotificationAction] = actionsData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let label = dict["label"] as? String else { return nil }
            return NotificationAction(
                id: id,
                label: label,
                webhook: dict["webhook"] as? String,
                destructive: dict["destructive"] as? Bool
            )
        }

        guard !actions.isEmpty else { return }

        let categoryId = content.categoryIdentifier
        guard categoryId.hasPrefix("BLIP_DYN_") else { return }

        NotificationCategories.registerDynamic(actions: actions, categoryId: categoryId)
    }

    private func handleDynamicAction(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) async -> Bool? {
        guard let actionsData = userInfo["actions"] as? [[String: Any]] else { return nil }

        // Find the matching action
        guard let actionDict = actionsData.first(where: { ($0["id"] as? String) == actionIdentifier }),
              let webhookURL = actionDict["webhook"] as? String else {
            return nil
        }

        await ActionWebhookService.fire(url: webhookURL)
        return true
    }
}

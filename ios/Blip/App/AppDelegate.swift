import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    var pushManager: PushNotificationManager?
    var notificationHandler: NotificationHandler?

    var pendingQuickActionType: QuickActionType?

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let actionType = QuickActionType(rawValue: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        Task { @MainActor in
            await handleQuickAction(actionType)
        }
        completionHandler(true)
    }

    @MainActor
    func handleQuickAction(_ actionType: QuickActionType) async {
        switch actionType {
        case .copyWebhook:
            NotificationCenter.default.post(name: .blipCopyWebhook, object: nil)
        case .sendTest:
            NotificationCenter.default.post(name: .blipSendTest, object: nil)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushManager?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushManager?.handleRegistrationError(error)
    }
}

extension Notification.Name {
    static let blipCopyWebhook = Notification.Name("blipCopyWebhook")
    static let blipSendTest = Notification.Name("blipSendTest")
}

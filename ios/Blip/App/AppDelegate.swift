import UserNotifications

#if canImport(UIKit)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var pushManager: PushNotificationManager?
    var notificationHandler: NotificationHandler?

    // Stores the quick action type to handle after the app finishes launching
    var pendingQuickActionType: QuickActionType?

    // Called when the app is already running and a shortcut is invoked
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

#else
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var pushManager: PushNotificationManager?
    var notificationHandler: NotificationHandler?

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushManager?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushManager?.handleRegistrationError(error)
    }
}
#endif

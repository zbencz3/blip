#if canImport(UIKit)
import UIKit

enum QuickActionType: String {
    case copyWebhook = "copy_webhook"
    case sendTest = "send_test"
}

enum QuickActions {
    @MainActor static func registerShortcuts() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: QuickActionType.copyWebhook.rawValue,
                localizedTitle: "Copy Webhook URL",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "doc.on.doc")
            ),
            UIApplicationShortcutItem(
                type: QuickActionType.sendTest.rawValue,
                localizedTitle: "Send Test",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "paperplane.fill")
            )
        ]
    }
}
#endif

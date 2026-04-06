import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        guard let actionsData = content.userInfo["actions"] as? [[String: Any]],
              content.categoryIdentifier.hasPrefix("BZAP_DYN_") else {
            contentHandler(content)
            return
        }

        let actions = actionsData.compactMap { dict -> UNNotificationAction? in
            guard let id = dict["id"] as? String,
                  let label = dict["label"] as? String else { return nil }
            let destructive = dict["destructive"] as? Bool ?? false
            return UNNotificationAction(
                identifier: id,
                title: label,
                options: destructive ? [.destructive] : []
            )
        }

        guard !actions.isEmpty else {
            contentHandler(content)
            return
        }

        let dynamicCategory = UNNotificationCategory(
            identifier: content.categoryIdentifier,
            actions: actions,
            intentIdentifiers: []
        )

        // Static categories — always include so we don't overwrite them
        let generalCategory = UNNotificationCategory(
            identifier: "BZAP_GENERAL",
            actions: [
                UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
            ],
            intentIdentifiers: []
        )
        let urlCategory = UNNotificationCategory(
            identifier: "BZAP_WITH_URL",
            actions: [
                UNNotificationAction(identifier: "OPEN_URL", title: "Open URL", options: .foreground),
                UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
            ],
            intentIdentifiers: []
        )

        // Register all categories, then deliver
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([generalCategory, urlCategory, dynamicCategory])

        // Give the system a moment to register the category
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

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

        // Register dynamic category for action buttons
        if let actionsData = content.userInfo["actions"] as? [[String: Any]] {
            let categoryId = content.categoryIdentifier

            if categoryId.hasPrefix("BZAP_DYN_") {
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

                let category = UNNotificationCategory(
                    identifier: categoryId,
                    actions: actions,
                    intentIdentifiers: []
                )

                let center = UNUserNotificationCenter.current()
                center.getNotificationCategories { existing in
                    var categories = existing
                    categories.insert(category)
                    center.setNotificationCategories(categories)

                    // Small delay to ensure category is registered before delivery
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        contentHandler(content)
                    }
                }
                return
            }
        }

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

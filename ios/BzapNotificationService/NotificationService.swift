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

                // Include static categories to avoid overwriting them
                let staticCategories: Set<UNNotificationCategory> = [
                    UNNotificationCategory(
                        identifier: "BZAP_GENERAL",
                        actions: [
                            UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                            UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
                        ],
                        intentIdentifiers: []
                    ),
                    UNNotificationCategory(
                        identifier: "BZAP_WITH_URL",
                        actions: [
                            UNNotificationAction(identifier: "OPEN_URL", title: "Open URL", options: .foreground),
                            UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                            UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
                        ],
                        intentIdentifiers: []
                    )
                ]

                // Merge: get existing dynamic categories, add new one, plus static
                let center = UNUserNotificationCenter.current()
                let semaphore = DispatchSemaphore(value: 0)
                var existingCategories: Set<UNNotificationCategory> = []

                center.getNotificationCategories { categories in
                    existingCategories = categories
                    semaphore.signal()
                }
                semaphore.wait()

                // Keep existing dynamic categories, add new one, always include static
                var merged = existingCategories.filter { $0.identifier.hasPrefix("BZAP_DYN_") }
                merged.insert(category)
                merged.formUnion(staticCategories)
                center.setNotificationCategories(merged)

                // Wait briefly for registration to take effect
                Thread.sleep(forTimeInterval: 0.05)
                contentHandler(content)
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

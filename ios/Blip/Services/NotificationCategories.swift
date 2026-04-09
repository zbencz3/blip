import UserNotifications

enum NotificationCategories {
    static let generalCategory = "BZAP_GENERAL"
    static let urlCategory = "BZAP_WITH_URL"

    static func register() {
        let copyAction = UNNotificationAction(
            identifier: "COPY_MESSAGE",
            title: "Copy Message",
            options: []
        )
        let openURLAction = UNNotificationAction(
            identifier: "OPEN_URL",
            title: "Open URL",
            options: .foreground
        )
        let markReadAction = UNNotificationAction(
            identifier: "MARK_READ",
            title: "Mark as Read",
            options: []
        )

        let generalCategory = UNNotificationCategory(
            identifier: Self.generalCategory,
            actions: [copyAction, markReadAction],
            intentIdentifiers: []
        )
        let urlCategory = UNNotificationCategory(
            identifier: Self.urlCategory,
            actions: [openURLAction, copyAction, markReadAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([generalCategory, urlCategory])
    }

    static func registerDynamic(actions: [NotificationAction], categoryId: String) {
        let center = UNUserNotificationCenter.current()
        let newActions: [UNNotificationAction] = actions.map { action in
            let isDestructive = action.destructive == true

            if action.type == "text_input" {
                let placeholder = action.textInputPlaceholder ?? "Type your response..."
                return UNTextInputNotificationAction(
                    identifier: action.id,
                    title: action.label,
                    options: isDestructive ? [.destructive] : [],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: placeholder
                )
            }

            return UNNotificationAction(
                identifier: action.id,
                title: action.label,
                options: isDestructive ? [.destructive] : []
            )
        }
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: newActions,
            intentIdentifiers: []
        )
        // Merge with all existing categories (preserves other dynamic categories)
        center.getNotificationCategories { existing in
            var categories = existing
            // Remove old version of this category if it exists, add updated one
            categories = categories.filter { $0.identifier != categoryId }
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }
}

import UserNotifications

enum NotificationCategories {
    static let generalCategory = "BLIP_GENERAL"
    static let urlCategory = "BLIP_WITH_URL"

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
        center.getNotificationCategories { existing in
            var categories = existing
            let newActions = actions.map { action in
                UNNotificationAction(
                    identifier: action.id,
                    title: action.label,
                    options: action.destructive == true ? [.destructive] : []
                )
            }
            let category = UNNotificationCategory(
                identifier: categoryId,
                actions: newActions,
                intentIdentifiers: []
            )
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }
}

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
        // Merge with known static categories to avoid overwriting them
        let generalCat = UNNotificationCategory(
            identifier: Self.generalCategory,
            actions: [
                UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
            ],
            intentIdentifiers: []
        )
        let urlCat = UNNotificationCategory(
            identifier: Self.urlCategory,
            actions: [
                UNNotificationAction(identifier: "OPEN_URL", title: "Open URL", options: .foreground),
                UNNotificationAction(identifier: "COPY_MESSAGE", title: "Copy Message", options: []),
                UNNotificationAction(identifier: "MARK_READ", title: "Mark as Read", options: [])
            ],
            intentIdentifiers: []
        )
        center.setNotificationCategories([generalCat, urlCat, category])
    }
}

import UserNotifications

extension UNNotificationContent {
    var blipOpenURL: String? {
        userInfo["open_url"] as? String
    }

    var blipFilterCriteria: String? {
        userInfo["filter_criteria"] as? String
    }

    var blipThreadId: String? {
        (userInfo["thread_id"] as? String) ?? (threadIdentifier.isEmpty ? nil : threadIdentifier)
    }

    var blipImageURL: String? {
        userInfo["image_url"] as? String
    }

    var blipActions: [NotificationAction]? {
        guard let actionsData = userInfo["actions"] as? [[String: Any]] else { return nil }
        let actions: [NotificationAction] = actionsData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let label = dict["label"] as? String else { return nil }
            return NotificationAction(
                id: id,
                label: label,
                webhook: dict["webhook"] as? String,
                destructive: dict["destructive"] as? Bool,
                responseChannel: dict["response_channel"] as? Bool,
                type: dict["type"] as? String,
                textInputPlaceholder: dict["text_input_placeholder"] as? String
            )
        }
        return actions.isEmpty ? nil : actions
    }
}

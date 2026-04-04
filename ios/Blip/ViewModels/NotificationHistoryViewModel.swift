import Foundation
import SwiftData

@MainActor
@Observable
final class NotificationHistoryViewModel {
    var sections: [(date: Date, notifications: [NotificationRecord])] = []
    var retention: RetentionPeriod = .oneMonth
    var showDeleteConfirmation = false

    private var store: NotificationStore?

    init() {
        if let saved = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.retentionPeriod),
           let period = RetentionPeriod(rawValue: saved) {
            retention = period
        }
    }

    func load(context: ModelContext) {
        store = NotificationStore(modelContext: context)
        refresh()
    }

    func refresh() {
        sections = store?.fetchGroupedByDate() ?? []
    }

    func deleteAll() {
        store?.deleteAll()
        refresh()
    }

    func setRetention(_ period: RetentionPeriod) {
        retention = period
        UserDefaults.standard.set(period.rawValue, forKey: Constants.UserDefaultsKeys.retentionPeriod)
        store?.purge(olderThan: period)
        refresh()
    }
}

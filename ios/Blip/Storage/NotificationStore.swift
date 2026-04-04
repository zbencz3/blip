import Foundation
import SwiftData

enum RetentionPeriod: String, CaseIterable, Identifiable {
    case oneWeek = "1 week"
    case oneMonth = "1 month"
    case threeMonths = "3 months"
    case forever = "Forever"

    var id: String { rawValue }

    var timeInterval: TimeInterval? {
        switch self {
        case .oneWeek: return 7 * 24 * 3600
        case .oneMonth: return 30 * 24 * 3600
        case .threeMonths: return 90 * 24 * 3600
        case .forever: return nil
        }
    }
}

struct NotificationStore {
    let modelContext: ModelContext

    func insert(
        title: String? = nil,
        subtitle: String? = nil,
        message: String? = nil,
        threadId: String? = nil,
        openURL: String? = nil
    ) {
        let record = NotificationRecord(
            title: title,
            subtitle: subtitle,
            message: message,
            threadId: threadId,
            openURL: openURL
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    func fetchAll() -> [NotificationRecord] {
        let descriptor = FetchDescriptor<NotificationRecord>(
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchGroupedByDate() -> [(date: Date, notifications: [NotificationRecord])] {
        let all = fetchAll()
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: all) { record in
            calendar.startOfDay(for: record.receivedAt)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, notifications: $0.value) }
    }

    func deleteAll() {
        do {
            try modelContext.delete(model: NotificationRecord.self)
            try modelContext.save()
        } catch {
            print("[NotificationStore] deleteAll failed: \(error)")
        }
    }

    func purge(olderThan retention: RetentionPeriod) {
        guard let interval = retention.timeInterval else { return }
        let cutoff = Date().addingTimeInterval(-interval)
        let predicate = #Predicate<NotificationRecord> { $0.receivedAt < cutoff }
        do {
            try modelContext.delete(model: NotificationRecord.self, where: predicate)
            try modelContext.save()
        } catch {
            print("[NotificationStore] purge failed: \(error)")
        }
    }
}

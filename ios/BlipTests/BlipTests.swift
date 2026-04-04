import Testing
import Foundation
import SwiftData
@testable import Blip

@Suite("Secret Generation")
struct SecretGenerationTests {
    @Test("Secret has correct prefix")
    func secretPrefix() {
        let secret = SecretManager.generateSecret()
        #expect(secret.hasPrefix("bps_usr_"))
    }

    @Test("Secret has correct length")
    func secretLength() {
        let secret = SecretManager.generateSecret()
        // bps_usr_ (8 chars) + 64 hex chars = 72
        #expect(secret.count == 72)
    }

    @Test("Secrets are unique")
    func secretsUnique() {
        let s1 = SecretManager.generateSecret()
        let s2 = SecretManager.generateSecret()
        #expect(s1 != s2)
    }
}

@Suite("Push Token Conversion")
struct PushTokenTests {
    @Test("Token data converts to hex string")
    func tokenToHex() {
        let data = Data([0xAB, 0xCD, 0xEF, 0x01, 0x23])
        let hex = PushNotificationManager.tokenToHex(data)
        #expect(hex == "abcdef0123")
    }

    @Test("Empty token data converts to empty string")
    func emptyTokenToHex() {
        let hex = PushNotificationManager.tokenToHex(Data())
        #expect(hex == "")
    }
}

@Suite("Device Model")
struct DeviceModelTests {
    @Test("Device decodes from JSON")
    func deviceDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "device_token": "abc123",
            "device_name": "iPhone",
            "device_secret": "bps_usr_test",
            "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let device = try decoder.decode(Device.self, from: json)
        #expect(device.deviceName == "iPhone")
        #expect(device.deviceToken == "abc123")
        #expect(device.deviceSecret == "bps_usr_test")
    }

    @Test("Device webhook URL constructed correctly")
    func deviceWebhookURL() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "device_token": "abc123",
            "device_name": "iPhone",
            "device_secret": "bps_usr_test"
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(Device.self, from: json)
        #expect(device.webhookURL?.contains("bps_usr_test") == true)
    }

    @Test("Device without secret has no webhook URL")
    func deviceNoSecret() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "device_token": "abc123",
            "device_name": "iPhone"
        }
        """.data(using: .utf8)!

        let device = try JSONDecoder().decode(Device.self, from: json)
        #expect(device.webhookURL == nil)
    }
}

@Suite("Retention Period")
struct RetentionPeriodTests {
    @Test("One week has correct interval")
    func oneWeek() {
        #expect(RetentionPeriod.oneWeek.timeInterval == TimeInterval(7 * 24 * 3600))
    }

    @Test("Forever has nil interval")
    func forever() {
        #expect(RetentionPeriod.forever.timeInterval == nil)
    }

    @Test("All cases have IDs")
    func allCasesHaveIDs() {
        for period in RetentionPeriod.allCases {
            #expect(!period.id.isEmpty)
        }
    }
}

@Suite("API Client Request Construction")
struct APIClientTests {
    @Test("Register device request body is correct")
    func registerRequestBody() throws {
        let body: [String: String] = [
            "secret": "test_secret",
            "device_token": "token123",
            "device_name": "iPhone"
        ]
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        #expect(decoded["secret"] == "test_secret")
        #expect(decoded["device_token"] == "token123")
        #expect(decoded["device_name"] == "iPhone")
    }
}

// MARK: - NotificationRecord Tests

@Suite("NotificationRecord displayText")
struct NotificationRecordTests {
    @Test("displayText returns title and message joined with colon when both present")
    func displayTextBoth() {
        let record = NotificationRecord(title: "Hello", message: "World")
        #expect(record.displayText == "Hello: World")
    }

    @Test("displayText returns title only when no message")
    func displayTextTitleOnly() {
        let record = NotificationRecord(title: "Only Title")
        #expect(record.displayText == "Only Title")
    }

    @Test("displayText returns message only when no title")
    func displayTextMessageOnly() {
        let record = NotificationRecord(message: "Only Message")
        #expect(record.displayText == "Only Message")
    }

    @Test("displayText returns empty string when both nil")
    func displayTextNone() {
        let record = NotificationRecord()
        #expect(record.displayText == "")
    }

    @Test("displayText ignores subtitle when title and message both present")
    func displayTextIgnoresSubtitle() {
        let record = NotificationRecord(title: "T", subtitle: "S", message: "M")
        #expect(record.displayText == "T: M")
    }

    @Test("displayText returns title when subtitle present but no message")
    func displayTextTitleSubtitleNoMessage() {
        let record = NotificationRecord(title: "Title", subtitle: "Sub")
        #expect(record.displayText == "Title")
    }
}

// MARK: - NotificationStore Tests

@Suite("NotificationStore")
struct NotificationStoreTests {

    private func makeStore() throws -> (NotificationStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = NotificationStore(modelContext: context)
        return (store, context)
    }

    @Test("insert adds a record retrievable via fetchAll")
    func insertAndFetch() throws {
        let (store, _) = try makeStore()
        store.insert(title: "Test", message: "Body")
        let all = store.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Test")
        #expect(all[0].message == "Body")
    }

    @Test("insert stores optional fields correctly")
    func insertOptionalFields() throws {
        let (store, _) = try makeStore()
        store.insert(
            title: "T",
            subtitle: "S",
            message: "M",
            threadId: "thread1",
            openURL: "https://example.com"
        )
        let all = store.fetchAll()
        #expect(all.count == 1)
        let record = all[0]
        #expect(record.subtitle == "S")
        #expect(record.threadId == "thread1")
        #expect(record.openURL == "https://example.com")
    }

    @Test("insert with nil fields stores nil values")
    func insertNilFields() throws {
        let (store, _) = try makeStore()
        store.insert()
        let all = store.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == nil)
        #expect(all[0].message == nil)
    }

    @Test("fetchAll returns records sorted newest first")
    func fetchAllSortedNewest() throws {
        let (store, _) = try makeStore()
        let now = Date()
        let older = now.addingTimeInterval(-3600)
        let newest = now.addingTimeInterval(3600)

        store.insert(title: "Middle")
        // Insert records with explicit receivedAt via direct model insertion
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let s = NotificationStore(modelContext: context)

        let r1 = NotificationRecord(title: "Old", receivedAt: older)
        let r2 = NotificationRecord(title: "New", receivedAt: newest)
        let r3 = NotificationRecord(title: "Mid", receivedAt: now)
        context.insert(r1)
        context.insert(r2)
        context.insert(r3)
        try context.save()

        let all = s.fetchAll()
        #expect(all.count == 3)
        #expect(all[0].title == "New")
        #expect(all[1].title == "Mid")
        #expect(all[2].title == "Old")
    }

    @Test("fetchAll returns empty array when no records")
    func fetchAllEmpty() throws {
        let (store, _) = try makeStore()
        #expect(store.fetchAll().isEmpty)
    }

    @Test("fetchAll returns multiple inserted records")
    func fetchAllMultiple() throws {
        let (store, _) = try makeStore()
        store.insert(title: "First")
        store.insert(title: "Second")
        store.insert(title: "Third")
        #expect(store.fetchAll().count == 3)
    }

    @Test("deleteAll removes all records")
    func deleteAllRemovesEverything() throws {
        let (store, _) = try makeStore()
        store.insert(title: "A")
        store.insert(title: "B")
        store.insert(title: "C")
        #expect(store.fetchAll().count == 3)
        store.deleteAll()
        #expect(store.fetchAll().isEmpty)
    }

    @Test("deleteAll on empty store does not throw")
    func deleteAllEmpty() throws {
        let (store, _) = try makeStore()
        store.deleteAll()
        #expect(store.fetchAll().isEmpty)
    }

    @Test("fetchGroupedByDate groups records by calendar day")
    func fetchGroupedByDate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = NotificationStore(modelContext: context)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)

        let r1 = NotificationRecord(title: "Today-1", receivedAt: today.addingTimeInterval(100))
        let r2 = NotificationRecord(title: "Today-2", receivedAt: today.addingTimeInterval(200))
        let r3 = NotificationRecord(title: "Yesterday", receivedAt: yesterday.addingTimeInterval(100))
        context.insert(r1)
        context.insert(r2)
        context.insert(r3)
        try context.save()

        let groups = store.fetchGroupedByDate()
        #expect(groups.count == 2)
        // Most recent day first
        #expect(groups[0].date == today)
        #expect(groups[0].notifications.count == 2)
        #expect(groups[1].date == yesterday)
        #expect(groups[1].notifications.count == 1)
    }

    @Test("fetchGroupedByDate returns empty array when store is empty")
    func fetchGroupedByDateEmpty() throws {
        let (store, _) = try makeStore()
        #expect(store.fetchGroupedByDate().isEmpty)
    }

    @Test("fetchGroupedByDate single record produces single group")
    func fetchGroupedByDateSingleRecord() throws {
        let (store, _) = try makeStore()
        store.insert(title: "Solo")
        let groups = store.fetchGroupedByDate()
        #expect(groups.count == 1)
        #expect(groups[0].notifications.count == 1)
    }

    @Test("purge removes records older than retention interval")
    func purgeRemovesOldRecords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = NotificationStore(modelContext: context)

        let now = Date()
        let eightDaysAgo = now.addingTimeInterval(-(8 * 24 * 3600))
        let oneDayAgo = now.addingTimeInterval(-(1 * 24 * 3600))

        let old = NotificationRecord(title: "Old", receivedAt: eightDaysAgo)
        let recent = NotificationRecord(title: "Recent", receivedAt: oneDayAgo)
        context.insert(old)
        context.insert(recent)
        try context.save()

        store.purge(olderThan: .oneWeek)

        let remaining = store.fetchAll()
        #expect(remaining.count == 1)
        #expect(remaining[0].title == "Recent")
    }

    @Test("purge with forever retention keeps all records")
    func purgeForeverKeepsAll() throws {
        let (store, _) = try makeStore()
        store.insert(title: "A")
        store.insert(title: "B")
        store.purge(olderThan: .forever)
        #expect(store.fetchAll().count == 2)
    }

    @Test("purge removes nothing when all records are within retention window")
    func purgeKeepsRecentRecords() throws {
        let (store, _) = try makeStore()
        // Insert a record from 1 hour ago — well within oneWeek
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let s = NotificationStore(modelContext: context)
        let r = NotificationRecord(title: "Fresh", receivedAt: Date().addingTimeInterval(-3600))
        context.insert(r)
        try context.save()

        s.purge(olderThan: .oneWeek)
        #expect(s.fetchAll().count == 1)
    }

    @Test("purge with oneMonth removes records older than 30 days")
    func purgeOneMonth() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = NotificationStore(modelContext: context)

        let now = Date()
        let thirtyOneDaysAgo = now.addingTimeInterval(-(31 * 24 * 3600))
        let twentyNineDaysAgo = now.addingTimeInterval(-(29 * 24 * 3600))

        context.insert(NotificationRecord(title: "TooOld", receivedAt: thirtyOneDaysAgo))
        context.insert(NotificationRecord(title: "JustFine", receivedAt: twentyNineDaysAgo))
        try context.save()

        store.purge(olderThan: .oneMonth)

        let remaining = store.fetchAll()
        #expect(remaining.count == 1)
        #expect(remaining[0].title == "JustFine")
    }

    @Test("purge with threeMonths removes records older than 90 days")
    func purgeThreeMonths() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: NotificationRecord.self, configurations: config)
        let context = ModelContext(container)
        let store = NotificationStore(modelContext: context)

        let now = Date()
        let ninetyOneDaysAgo = now.addingTimeInterval(-(91 * 24 * 3600))
        let eightyNineDaysAgo = now.addingTimeInterval(-(89 * 24 * 3600))

        context.insert(NotificationRecord(title: "VeryOld", receivedAt: ninetyOneDaysAgo))
        context.insert(NotificationRecord(title: "OK", receivedAt: eightyNineDaysAgo))
        try context.save()

        store.purge(olderThan: .threeMonths)

        let remaining = store.fetchAll()
        #expect(remaining.count == 1)
        #expect(remaining[0].title == "OK")
    }
}

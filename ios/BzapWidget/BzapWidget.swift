import WidgetKit
import SwiftUI

// MARK: - Data

struct MonitorEntry: TimelineEntry {
    let date: Date
    let monitors: [WidgetMonitor]
    let isPlaceholder: Bool

    var upCount: Int { monitors.filter { $0.status == "up" }.count }
    var downCount: Int { monitors.filter { $0.status == "down" }.count }
    var pausedCount: Int { monitors.filter { $0.status == "paused" }.count }
    var hasIssues: Bool { downCount > 0 }

    static let placeholder = MonitorEntry(
        date: .now,
        monitors: [
            WidgetMonitor(name: "API Server", status: "up", type: "http"),
            WidgetMonitor(name: "Cron Job", status: "up", type: "heartbeat"),
            WidgetMonitor(name: "Website", status: "down", type: "http"),
        ],
        isPlaceholder: true
    )

    static let empty = MonitorEntry(date: .now, monitors: [], isPlaceholder: false)
}

struct WidgetMonitor: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let type: String

    var isHeartbeat: Bool { type == "heartbeat" }
}

// MARK: - Provider

struct MonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonitorEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (MonitorEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @Sendable in
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<MonitorEntry>) -> Void) {
        Task { @Sendable in
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> MonitorEntry {
        let keychain = WidgetKeychainService()
        guard let secret = keychain.load(key: "user_secret") else {
            return .empty
        }

        do {
            let monitors = try await WidgetAPIClient.fetchMonitors(secret: secret)
            return MonitorEntry(
                date: .now,
                monitors: monitors.map { WidgetMonitor(name: $0.name, status: $0.status, type: $0.type) },
                isPlaceholder: false
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Keychain (lightweight, no shared framework needed)

struct WidgetKeychainService {
    let service = "com.isylva.boopsy"

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: "7TH7A8M6P4.com.isylva.boopsy",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - API Client (lightweight)

struct WidgetAPIClient {
    struct MonitorResponse: Codable {
        let name: String
        let status: String
        let type: String
    }

    static func fetchMonitors(secret: String) async throws -> [MonitorResponse] {
        let url = URL(string: "https://bzap-server.fly.dev/v1/monitors")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }
        return try JSONDecoder().decode([MonitorResponse].self, from: data)
    }
}

// MARK: - Widget Views

struct BzapWidgetEntryView: View {
    var entry: MonitorEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            mediumWidget
        }
    }

    // MARK: Small — Up/Down counts

    private var smallWidget: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.36))
                Text("bzap")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.36))
            }

            if entry.monitors.isEmpty && !entry.isPlaceholder {
                Text("No monitors")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(entry.upCount)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                        Text("UP")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(entry.downCount)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(entry.downCount > 0 ? .red : .secondary.opacity(0.4))
                        Text("DOWN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.05, green: 0.05, blue: 0.05)
        }
    }

    // MARK: Medium — Monitor list

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.36))
                    Text("bzap")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.36))
                }
                Spacer()
                if entry.hasIssues {
                    Text("DEGRADED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.15))
                        .clipShape(Capsule())
                } else if !entry.monitors.isEmpty {
                    Text("ALL UP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if entry.monitors.isEmpty && !entry.isPlaceholder {
                Spacer()
                Text("No monitors configured")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.monitors.prefix(4)) { monitor in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor(monitor.status))
                            .frame(width: 6, height: 6)
                        Image(systemName: monitor.isHeartbeat ? "heart.fill" : "globe")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text(monitor.name)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(monitor.status.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor(monitor.status))
                    }
                }
                if entry.monitors.count > 4 {
                    Text("+\(entry.monitors.count - 4) more")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.05, green: 0.05, blue: 0.05)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "up": return .green
        case "down": return .red
        case "paused": return .orange
        default: return .orange
        }
    }
}

// MARK: - Widget Configuration

@main
struct BzapWidget: Widget {
    let kind = "BzapMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonitorProvider()) { entry in
            BzapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Monitors")
        .description("Monitor uptime at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

struct MenuBarView: View {
    let secretManager: SecretManager

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotificationRecord.receivedAt, order: .reverse)
    private var allNotifications: [NotificationRecord]
    @State private var copiedField: CopiedField?

    private enum CopiedField {
        case curl, url
    }

    private var recentNotifications: [NotificationRecord] {
        Array(allNotifications.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            webhookSection
            Divider().padding(.vertical, 4)
            quickActionsSection
            Divider().padding(.vertical, 4)
            notificationsSection
            Divider().padding(.vertical, 4)
            footerSection
        }
        .frame(width: 320)
        .padding(12)
    }

    // MARK: - Webhook Section

    private var webhookSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Webhook URL", systemImage: "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(secretManager.webhookURL)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(BlipColors.textCode)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(BlipColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            menuButton(
                title: "Copy curl Command",
                icon: "doc.on.clipboard",
                shortcutHint: "⌘⇧B",
                isCopied: copiedField == .curl
            ) {
                copyToPasteboard(secretManager.curlCommand)
                flashCopied(.curl)
            }

            menuButton(
                title: "Copy Webhook URL",
                icon: "link",
                shortcutHint: nil,
                isCopied: copiedField == .url
            ) {
                copyToPasteboard(secretManager.webhookURL)
                flashCopied(.url)
            }

            menuButton(
                title: "Send Test Notification",
                icon: "paperplane",
                shortcutHint: nil,
                isCopied: false
            ) {
                Task {
                    try? await APIClient().sendTest(secret: secretManager.currentSecret)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Recent", systemImage: "bell")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)

            if recentNotifications.isEmpty {
                Text("No notifications yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentNotifications) { notification in
                    HStack(alignment: .top, spacing: 8) {
                        Text(notification.displayText)
                            .font(.system(size: 13))
                            .foregroundStyle(BlipColors.textPrimary)
                            .lineLimit(2)
                        Spacer()
                        Text(notification.receivedAt, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            menuButton(
                title: "Open Blip",
                icon: "macwindow",
                shortcutHint: nil,
                isCopied: false
            ) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: {
                    $0.canBecomeMain
                }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            menuButton(
                title: "Quit",
                icon: "power",
                shortcutHint: "⌘Q",
                isCopied: false
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Helpers

    private func menuButton(
        title: String,
        icon: String,
        shortcutHint: String?,
        isCopied: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(isCopied ? "Copied!" : title, systemImage: isCopied ? "checkmark" : icon)
                    .font(.system(size: 13))
                Spacer()
                if let shortcutHint {
                    Text(shortcutHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .cornerRadius(4)
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func flashCopied(_ field: CopiedField) {
        copiedField = field
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedField == field {
                copiedField = nil
            }
        }
    }
}
#endif

import SwiftUI

struct UseCasesView: View {
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Two-way actions hero
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(BlipColors.accentPurple)
                                Text("TWO-WAY ACTIONS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(BlipColors.accentPurple)
                            }

                            Text("Notifications that do things")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(BlipColors.textPrimary)

                            Text("Add action buttons that fire webhooks back when tapped. Your phone becomes a remote control.")
                                .font(.system(size: 14))
                                .foregroundStyle(BlipColors.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BlipColors.accentPurple.opacity(0.3), lineWidth: 1)
                        )

                        // Action examples
                        VStack(spacing: 8) {
                            ForEach(ActionExample.all) { example in
                                ActionExampleRow(example: example)
                            }
                        }

                        // QR Code section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(BlipColors.accentPurple)
                                Text("QR CODE SHARING")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(BlipColors.accentPurple)
                            }

                            Text("Share your webhook instantly")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(BlipColors.textPrimary)

                            Text("Your webhook URL as a scannable QR code. No typing, no copy-paste across devices.")
                                .font(.system(size: 14))
                                .foregroundStyle(BlipColors.textSecondary)
                                .lineSpacing(3)

                            VStack(alignment: .leading, spacing: 8) {
                                qrExample(icon: "desktopcomputer", text: "Scan from your laptop to set up CI/CD pipelines")
                                qrExample(icon: "person.2.fill", text: "Let a teammate scan it to send you notifications")
                                qrExample(icon: "server.rack", text: "Set up multiple machines without messaging URLs to yourself")
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                        )

                        // Use cases header
                        Text("Use Cases")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(BlipColors.accentPurple)
                            .padding(.top, 8)

                        Text("Built for people who build things")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(BlipColors.textPrimary)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(UseCase.all) { useCase in
                                UseCaseCard(useCase: useCase)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Use Cases")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func qrExample(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(BlipColors.accentPurple)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(BlipColors.textSecondary)
        }
    }
}

// MARK: - Action Example

struct ActionExample: Identifiable {
    let id = UUID()
    let notification: String
    let buttons: [ActionButton]

    struct ActionButton {
        let label: String
        let style: ButtonStyle
        enum ButtonStyle { case primary, secondary, danger }
    }

    static let all: [ActionExample] = [
        ActionExample(
            notification: "🚀 Deploy v2.3.1 ready — all tests passing",
            buttons: [
                .init(label: "Deploy to Prod", style: .primary),
                .init(label: "Rollback", style: .danger)
            ]
        ),
        ActionExample(
            notification: "🏠 Motion detected in garage — 11:42 PM",
            buttons: [
                .init(label: "Turn On Lights", style: .primary),
                .init(label: "Lock Door", style: .secondary)
            ]
        ),
        ActionExample(
            notification: "📡 API down — 502 for 2 minutes",
            buttons: [
                .init(label: "Restart", style: .primary),
                .init(label: "Scale Up", style: .secondary)
            ]
        ),
        ActionExample(
            notification: "🤖 feat: add auth — 12 tests pass",
            buttons: [
                .init(label: "Approve", style: .primary),
                .init(label: "Reject", style: .danger)
            ]
        ),
    ]
}

private struct ActionExampleRow: View {
    let example: ActionExample

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(example.notification)
                .font(.system(size: 13))
                .foregroundStyle(BlipColors.textPrimary)

            HStack(spacing: 6) {
                Text("→")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                ForEach(Array(example.buttons.enumerated()), id: \.offset) { _, button in
                    Text(button.label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(buttonColor(button.style))
                        .foregroundStyle(buttonTextColor(button.style))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    private func buttonColor(_ style: ActionExample.ActionButton.ButtonStyle) -> Color {
        switch style {
        case .primary: BlipColors.accentGreen
        case .secondary: Color(white: 0.2)
        case .danger: Color(red: 1, green: 0.27, blue: 0.23)
        }
    }

    private func buttonTextColor(_ style: ActionExample.ActionButton.ButtonStyle) -> Color {
        switch style {
        case .primary: .black
        case .secondary: .white
        case .danger: .white
        }
    }
}

// MARK: - Use Case Model

struct UseCase: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let description: String
    let example: String
    let action: String

    static let all: [UseCase] = [
        UseCase(
            emoji: "🏠",
            title: "Home Automation",
            description: "Motion alerts, leak detection, temperature drops. Tap a button to turn on lights or lock doors.",
            example: "\"Motion detected in garage\"",
            action: "[Turn On Lights] [Lock Door]"
        ),
        UseCase(
            emoji: "🚀",
            title: "CI/CD Pipelines",
            description: "Know the moment your build passes or fails. Approve deploys from the notification.",
            example: "\"Deploy v2.3.1 ready\"",
            action: "[Deploy to Prod] [Rollback]"
        ),
        UseCase(
            emoji: "🤖",
            title: "AI Coding Sessions",
            description: "Using Claude Code or Copilot? Get notified when tasks finish. Review from your phone.",
            example: "\"feat: add auth — 12 tests pass\"",
            action: "[Approve] [Reject]"
        ),
        UseCase(
            emoji: "📡",
            title: "Server Monitoring",
            description: "Uptime checks, error spikes, disk warnings. Restart services with one tap.",
            example: "\"API down — 502 for 2 min\"",
            action: "[Restart] [Scale Up]"
        ),
        UseCase(
            emoji: "📜",
            title: "Cron Jobs & Scripts",
            description: "Backups, data exports, ML training. Fire and forget, get pinged when done.",
            example: "\"Backup complete: 12.4 GB\"",
            action: "[View Log] [Dismiss]"
        ),
        UseCase(
            emoji: "🔔",
            title: "Anything with HTTP",
            description: "If it can make an HTTP request, it can send you a Bzap. Python, Node, Go, Bash, Zapier.",
            example: "requests.post(url, json=",
            action: "  {\"message\": \"Hello!\"})"
        ),
    ]
}

// MARK: - Use Case Card

private struct UseCaseCard: View {
    let useCase: UseCase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(useCase.emoji)
                    .font(.system(size: 22))
                Text(useCase.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BlipColors.textPrimary)
                    .lineLimit(2)
            }

            Text(useCase.description)
                .font(.system(size: 12))
                .foregroundStyle(BlipColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(useCase.example)
                Text("→ " + useCase.action)
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Color(red: 0, green: 0.85, blue: 0.49))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }
}

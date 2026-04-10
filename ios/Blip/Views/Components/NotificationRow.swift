import SwiftUI

struct NotificationRow: View {
    let notification: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(BlipColors.accentPurple)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                if let title = notification.title, !title.isEmpty {
                    Text(title)
                        .font(BlipFonts.label)
                        .foregroundStyle(BlipColors.textPrimary)
                        .lineLimit(2)
                }

                if let message = notification.message, !message.isEmpty {
                    Text(message)
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)
                        .lineLimit(3)
                }

                if let subtitle = notification.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BlipFonts.helper)
                        .foregroundStyle(BlipColors.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text(notification.receivedAt, style: .time)
                .font(BlipFonts.metadata)
                .foregroundStyle(BlipColors.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

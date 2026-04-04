import SwiftUI

struct NotificationRow: View {
    let notification: NotificationRecord

    var body: some View {
        HStack(alignment: .top) {
            Text(notification.displayText)
                .font(BlipFonts.body)
                .foregroundStyle(BlipColors.textPrimary)
                .lineLimit(3)

            Spacer()

            Text(notification.receivedAt, style: .time)
                .font(BlipFonts.caption)
                .foregroundStyle(BlipColors.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

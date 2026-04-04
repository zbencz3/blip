import SwiftUI

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String?
    var showChevron = false
    var showExternalLink = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BlipFonts.body)
                    .foregroundStyle(BlipColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BlipColors.textSecondary)
            }
            if showExternalLink {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 13))
                    .foregroundStyle(BlipColors.textSecondary)
            }
        }
        .padding(.vertical, 10)
    }
}

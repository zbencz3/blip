import SwiftUI

struct WebhookQRSheet: View {
    let webhookURL: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColors.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(BlipColors.cardBackground)
                            .clipShape(Circle())
                    }
                }

                Text("Scan to get your webhook URL")
                    .font(BlipFonts.sectionHeader)
                    .foregroundStyle(BlipColors.textPrimary)

                QRCodeView(url: webhookURL, size: 240)
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(webhookURL)
                    .font(BlipFonts.code)
                    .foregroundStyle(BlipColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("Scan this QR code from another device or share it to quickly set up webhook integrations.")
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

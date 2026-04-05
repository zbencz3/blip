import SwiftUI

struct WebhookQRSheet: View {
    let webhookURL: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Scan to get your webhook URL")
                            .font(BlipFonts.sectionHeader)
                            .foregroundStyle(BlipColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)

                        QRCodeView(url: webhookURL, size: 200)
                            .padding(16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(webhookURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(BlipColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("Scan this QR code from another device or share it to quickly set up webhook integrations.")
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

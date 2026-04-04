import SwiftUI

struct CurlSnippetCard: View {
    let command: String
    var onSendTest: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bash")
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
                Spacer()
                if let onSendTest {
                    Button {
                        Task { await onSendTest() }
                    } label: {
                        Label("Send Test", systemImage: "paperplane.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BlipColors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BlipColors.cardBorder)
                            .clipShape(Capsule())
                    }
                }
            }

            Text(command)
                .font(BlipFonts.code)
                .foregroundStyle(BlipColors.textPrimary)
                .lineLimit(3)
        }
        .padding()
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }
}

import SwiftUI

struct TrialBannerView: View {
    let trialManager: TrialManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: trialManager.isTrialActive ? "heart.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(BlipColors.accentPurple)
            VStack(alignment: .leading, spacing: 2) {
                if trialManager.isTrialActive {
                    HStack(spacing: 0) {
                        Text("Your free access ends ")
                            .foregroundStyle(BlipColors.textPrimary)
                        Text(trialManager.trialEndDateFormatted)
                            .foregroundStyle(BlipColors.accentGreen)
                        Text(".")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                    .font(BlipFonts.caption)
                    Text("Subscribe before then to keep pushes coming.")
                        .font(.system(size: 11))
                        .foregroundStyle(BlipColors.textSecondary)
                } else {
                    Text("Your free trial has ended.")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textPrimary)
                    Text("Subscribe to keep receiving notifications.")
                        .font(.system(size: 11))
                        .foregroundStyle(BlipColors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

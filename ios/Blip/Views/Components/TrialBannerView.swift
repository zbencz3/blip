import SwiftUI

struct TrialBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundStyle(BlipColors.accentPurple)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Your free access ends ")
                        .foregroundStyle(BlipColors.textPrimary)
                    Text(Constants.trialEndDate)
                        .foregroundStyle(BlipColors.accentGreen)
                    Text(".")
                        .foregroundStyle(BlipColors.textPrimary)
                }
                .font(BlipFonts.caption)
                Text("Subscribe before then to keep pushes coming.")
                    .font(.system(size: 11))
                    .foregroundStyle(BlipColors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

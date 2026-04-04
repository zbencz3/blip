import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("bzap \(version)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(BlipColors.textPrimary)

                // App icon
                Image("AppIcon")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: BlipColors.accentPurple.opacity(0.4), radius: 20)

                Spacer()

                VStack(spacing: 4) {
                    Text("bzap \(version) (\(build))")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)
                    Text("Made with ❤️ by iSylva")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

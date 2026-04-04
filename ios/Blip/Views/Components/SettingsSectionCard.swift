import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

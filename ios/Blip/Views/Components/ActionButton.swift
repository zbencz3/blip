import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    enum Style {
        case primary   // green/lime
        case secondary // white
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var foregroundColor: Color {
        .black
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return BlipColors.accentGreen
        case .secondary: return .white
        }
    }
}

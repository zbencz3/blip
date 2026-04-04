import SwiftUI

struct RetentionPicker: View {
    @Binding var selection: RetentionPeriod

    var body: some View {
        Menu {
            ForEach(RetentionPeriod.allCases) { period in
                Button {
                    selection = period
                } label: {
                    HStack {
                        Text("Keep for \(period.rawValue)")
                        if period == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Settings")
                    .font(BlipFonts.body)
                    .foregroundStyle(BlipColors.textPrimary)
                Spacer()
                Text("Keep for \(selection.rawValue)")
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(BlipColors.textSecondary)
            }
            .padding()
            .background(BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

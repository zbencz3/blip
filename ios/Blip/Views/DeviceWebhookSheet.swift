import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct DeviceWebhookSheet: View {
    let device: Device
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            VStack(spacing: 20) {
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

                HStack(spacing: 4) {
                    Text("Send a notification to")
                    Image(systemName: "iphone")
                    Text(device.deviceName)
                        .fontWeight(.semibold)
                    Text("only using this webhook.")
                }
                .font(BlipFonts.body)
                .foregroundStyle(BlipColors.textPrimary)
                .multilineTextAlignment(.center)

                if let command = device.curlCommand {
                    CurlSnippetCard(command: command)

                    HStack(spacing: 12) {
                        ActionButton(title: "Copy", icon: "doc.on.doc", style: .primary) {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = command
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                            #endif
                        }
                        ShareLink(item: command) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

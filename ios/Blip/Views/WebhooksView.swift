import SwiftUI

struct WebhooksView: View {
    @State private var viewModel: WebhooksViewModel
    @State private var selectedDevice: Device?
    @State private var showQRCode = false

    init(secretManager: SecretManager, apiClient: APIClient = APIClient()) {
        _viewModel = State(initialValue: WebhooksViewModel(secretManager: secretManager, apiClient: apiClient))
    }

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Warning banner
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(BlipColors.accentYellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep your webhook URLs private")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(BlipColors.textPrimary)
                            Text("Anyone with access can send notifications to your devices.")
                                .font(BlipFonts.caption)
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                    }
                    .padding()
                    .background(BlipColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Send to All Devices
                    Text("Send to All Devices")
                        .font(BlipFonts.sectionHeader)
                        .foregroundStyle(BlipColors.accentPurple)

                    Text("Send notifications to **all your devices** with this webhook.")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)

                    CurlSnippetCard(command: viewModel.mainCurlCommand) {
                        try? await viewModel.apiClient.sendTest(secret: viewModel.secretManager.currentSecret)
                    }

                    HStack(spacing: 12) {
                        ActionButton(title: "Copy", icon: "doc.on.doc", style: .primary) {
                            viewModel.copyMainWebhook()
                        }
                        ShareLink(item: viewModel.mainCurlCommand) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { showQRCode = true } label: {
                            Image(systemName: "qrcode")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 48)
                                .background(BlipColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                                )
                        }
                    }

                    if let lastUsed = viewModel.lastWebhookUsed {
                        Label("Webhook was used \(lastUsed, style: .date) at \(lastUsed, style: .time).", systemImage: "link")
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                    }

                    // Send to Single Device
                    Text("Send to a Single Device")
                        .font(BlipFonts.sectionHeader)
                        .foregroundStyle(BlipColors.accentPurple)
                        .padding(.top, 8)

                    Text("Send notifications to a **single device** using its webhook.")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)

                    ForEach(viewModel.devices) { device in
                        Button { selectedDevice = device } label: {
                            HStack {
                                Image(systemName: "iphone")
                                    .foregroundStyle(BlipColors.textSecondary)
                                Text(device.deviceName)
                                    .font(BlipFonts.body)
                                    .foregroundStyle(BlipColors.textPrimary)
                                if viewModel.isCurrentDevice(device) {
                                    Text("This Device")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(BlipColors.accentGreen)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(BlipColors.accentGreen.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(BlipColors.textSecondary)
                            }
                            .padding()
                            .background(BlipColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Webhooks")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { @MainActor in await viewModel.loadDevices() }
        .sheet(item: $selectedDevice) { device in
            DeviceWebhookSheet(device: device)
        }
        .sheet(isPresented: $showQRCode) {
            WebhookQRSheet(webhookURL: viewModel.mainWebhookURL)
        }
    }
}

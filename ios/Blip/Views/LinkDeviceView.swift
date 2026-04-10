import SwiftUI
import CoreImage.CIFilterBuiltins

struct LinkDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    let secretManager: SecretManager
    let apiClient: APIClient

    @State private var mode: LinkMode = .choose
    @State private var showScanner = false
    @State private var linkSuccess = false
    @State private var error: String?

    enum LinkMode {
        case choose, showQR, scanning, importing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        switch mode {
                        case .choose:
                            chooseView
                        case .showQR:
                            showQRView
                        case .scanning:
                            EmptyView()
                        case .importing:
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(BlipColors.accentGreen)
                                Text("Linking device...")
                                    .font(BlipFonts.label)
                                    .foregroundStyle(BlipColors.textSecondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Link Device")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner, onDismiss: {
                if mode == .scanning { mode = .choose }
            }) {
                QRScannerView { scannedSecret in
                    showScanner = false
                    mode = .importing
                    Task { await importSecret(scannedSecret) }
                }
            }
            .alert("Device Linked!", isPresented: $linkSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("This device is now linked to your account. Notifications will be sent to all your devices.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Choose

    private var chooseView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(BlipFonts.hero)
                    .foregroundStyle(BlipColors.accentPurple)
                Text("Link another device")
                    .font(BlipFonts.title)
                    .foregroundStyle(BlipColors.textPrimary)
                Text("Share your account between iPhone and iPad.")
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
            }
            .padding(.bottom, 8)

            // Option 1: Show QR (this device has the account)
            Button { mode = .showQR } label: {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(BlipFonts.titleLarge)
                        .foregroundStyle(BlipColors.accentGreen)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show QR Code")
                            .font(BlipFonts.cardTitle)
                            .foregroundStyle(BlipColors.textPrimary)
                        Text("Display on this device, scan from the other")
                            .font(BlipFonts.helper)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BlipColors.textSecondary)
                }
                .padding(16)
                .background(BlipColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                )
            }

            // Option 2: Scan QR (this device is new)
            Button {
                mode = .scanning
                showScanner = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(BlipFonts.titleLarge)
                        .foregroundStyle(BlipColors.accentPurple)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan QR Code")
                            .font(BlipFonts.cardTitle)
                            .foregroundStyle(BlipColors.textPrimary)
                        Text("Scan from the device that has your account")
                            .font(BlipFonts.helper)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(BlipColors.textSecondary)
                }
                .padding(16)
                .background(BlipColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                )
            }

            if let error {
                Text(error)
                    .font(BlipFonts.small)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Show QR

    private var showQRView: some View {
        VStack(spacing: 20) {
            Text("Scan this from your other device")
                .font(BlipFonts.label)
                .foregroundStyle(BlipColors.textSecondary)

            if let image = generateQR(from: secretManager.currentSecret) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text("This QR contains your account secret.\nDo not share it publicly.")
                .font(BlipFonts.helper)
                .foregroundStyle(BlipColors.textSecondary)
                .multilineTextAlignment(.center)

            Button { mode = .choose } label: {
                Text("Back")
                    .font(BlipFonts.cardTitle)
                    .foregroundStyle(BlipColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BlipColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Helpers

    private func generateQR(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func importSecret(_ secret: String) async {
        guard secret.hasPrefix("bps_usr_") else {
            error = "Invalid QR code. Expected a Bzap account secret."
            mode = .choose
            return
        }

        do {
            let keychain = KeychainService()
            try keychain.save(secret, for: Constants.Keychain.secretKey)
            secretManager.updateSecret(secret)

            // Re-register this device with the imported secret
            let deviceToken = UserDefaults.standard.string(forKey: "device_token") ?? ""
            if !deviceToken.isEmpty {
                _ = try await apiClient.registerDevice(
                    secret: secret,
                    deviceToken: deviceToken,
                    deviceName: UIDevice.current.name
                )
            }

            linkSuccess = true
        } catch {
            self.error = "Failed to link: \(error.localizedDescription)"
            mode = .choose
        }
    }
}

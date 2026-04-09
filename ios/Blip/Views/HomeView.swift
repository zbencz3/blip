import AVFoundation
import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    let trialManager: TrialManager
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showCopied = false
    @State private var showQRCode = false
    @State private var showTemplates = false
    @State private var showSubscription = false
    @State private var showUseCases = false
    @State private var statusOn = true
    @State private var startupPlayer: AVAudioPlayer?
    @State private var hasPlayedStartup = false

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Navigation bar
                    HStack {
                        Button { showNotifications = true } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20))
                                .foregroundStyle(BlipColors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(BlipColors.cardBackground)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(BlipColors.cardBorder, lineWidth: 0.5))
                        }
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(BlipColors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(BlipColors.cardBackground)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(BlipColors.cardBorder, lineWidth: 0.5))
                        }
                    }

                    Spacer().frame(height: 20)

                    // Hero with lightning bolt
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(BlipColors.accentPurple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("bzap")
                                .font(.system(size: 44, weight: .black, design: .monospaced))
                                .foregroundStyle(BlipColors.accentPurple)
                            Text("push notifications via webhook")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                    }

                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .opacity(statusOn ? 1.0 : 0)
                        Text("Ready to receive")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                    .onAppear { startStatusLoop() }

                    // Curl snippet
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("$")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.accentPurple)
                            Text("Quick start")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                            Spacer()
                            Menu {
                                Button {
                                    Task { await viewModel.sendTest() }
                                } label: {
                                    Label("Simple Notification", systemImage: "bell.fill")
                                }
                                Button {
                                    Task { await viewModel.sendTestWithActions() }
                                } label: {
                                    Label("With Action Buttons", systemImage: "arrow.left.arrow.right")
                                }
                                Button {
                                    Task { await viewModel.sendTestWithResponseChannel() }
                                } label: {
                                    Label("With Response Channel", systemImage: "text.bubble.fill")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Test")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(BlipColors.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(BlipColors.cardBorder)
                                .clipShape(Capsule())
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(viewModel.curlCommand)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(BlipColors.textCode)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(16)
                    .background(BlipColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                    )

                    // Action buttons
                    HStack(spacing: 10) {
                        Button {
                            viewModel.copyToClipboard()
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopied = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied!" : "Copy")
                            }
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(BlipColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        ShareLink(item: viewModel.curlCommand) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Features row — tappable
                    HStack(spacing: 12) {
                        Button { showQRCode = true } label: {
                            featurePill(icon: "qrcode", text: "QR Code")
                        }
                        Button { showTemplates = true } label: {
                            featurePill(icon: "doc.text", text: "Templates")
                        }
                        Button { showUseCases = true } label: {
                            featurePill(icon: "lightbulb.fill", text: "Use Cases")
                        }
                    }

                    Spacer().frame(height: 10)

                    // Trial banner — tap opens subscription
                    Button { showSubscription = true } label: {
                        TrialBannerView(trialManager: trialManager)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(secretManager: viewModel.secretManager, apiClient: viewModel.apiClient, trialManager: trialManager)
        }
        .sheet(isPresented: $showNotifications) {
            RecentNotificationsView()
        }
        .sheet(isPresented: $showQRCode) {
            WebhookQRSheet(webhookURL: viewModel.webhookURL)
        }
        .sheet(isPresented: $showTemplates) {
            NavigationStack {
                TemplatesView(secretManager: viewModel.secretManager)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showUseCases) {
            UseCasesView()
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView(trialManager: trialManager)
            }
            .preferredColorScheme(.dark)
        }
        .onAppear { playStartupSound() }
    }

    private func playStartupSound() {
        guard !hasPlayedStartup,
              !UserDefaults.standard.bool(forKey: "startup_sound_disabled") else { return }
        hasPlayedStartup = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let url = Bundle.main.url(forResource: "dialup", withExtension: "wav") else { return }
            startupPlayer = try? AVAudioPlayer(contentsOf: url)
            startupPlayer?.volume = 0.5
            startupPlayer?.play()
        }
    }

    private func startStatusLoop() {
        Task {
            while true {
                try? await Task.sleep(for: .milliseconds(800))
                statusOn = false
                try? await Task.sleep(for: .milliseconds(400))
                statusOn = true
            }
        }
    }

    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(BlipColors.accentPurple)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }
}

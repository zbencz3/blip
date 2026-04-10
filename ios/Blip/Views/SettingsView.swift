import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let secretManager: SecretManager
    let apiClient: APIClient
    let trialManager: TrialManager

    @State private var showWebhooks = false
    @State private var showSubscription = false
    @State private var showAbout = false
    @State private var showTemplates = false
    @State private var showMonitors = false
    @State private var showLinkDevice = false

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Subscription
                        SettingsSectionCard {
                            Button { showSubscription = true } label: {
                                SettingsRow(
                                    icon: "heart.fill",
                                    iconColor: BlipColors.accentPurple,
                                    title: "Subscription",
                                    subtitle: trialManager.isTrialActive ? "Your free access ends \(trialManager.trialEndDateFormatted)." : "Your free trial has ended.",
                                    showChevron: true
                                )
                            }
                        }

                        // Webhooks & Monitors
                        SettingsSectionCard {
                            Button { showWebhooks = true } label: {
                                SettingsRow(
                                    icon: "bolt.fill",
                                    iconColor: .blue,
                                    title: "Webhooks",
                                    showChevron: true
                                )
                            }
                            Divider().background(BlipColors.cardBorder)
                            Button { showMonitors = true } label: {
                                SettingsRow(
                                    icon: "chart.bar.fill",
                                    iconColor: .green,
                                    title: "Monitors",
                                    showChevron: true
                                )
                            }
                        }

                        // Link Device
                        SettingsSectionCard {
                            Button { showLinkDevice = true } label: {
                                SettingsRow(
                                    icon: "link.circle.fill",
                                    iconColor: BlipColors.accentPurple,
                                    title: "Link Device",
                                    subtitle: "Use Bzap on iPhone + iPad",
                                    showChevron: true
                                )
                            }
                        }

                        // Docs, Guides, Send Test
                        SettingsSectionCard {
                            Button {
                                openURL("https://zbencz3.github.io/blip/#docs")
                            } label: {
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    iconColor: .orange,
                                    title: "Documentation",
                                    showExternalLink: true
                                )
                            }
                            Divider().background(BlipColors.cardBorder)
                            Button {
                                openURL("https://zbencz3.github.io/blip/")
                            } label: {
                                SettingsRow(
                                    icon: "graduationcap.fill",
                                    iconColor: .green,
                                    title: "Guides",
                                    showExternalLink: true
                                )
                            }
                            Divider().background(BlipColors.cardBorder)
                            Button { showTemplates = true } label: {
                                SettingsRow(
                                    icon: "doc.text.magnifyingglass",
                                    iconColor: .cyan,
                                    title: "Templates"
                                )
                            }
                            Divider().background(BlipColors.cardBorder)
                            Button {
                                Task {
                                    try? await apiClient.sendTest(secret: secretManager.currentSecret)
                                }
                            } label: {
                                SettingsRow(
                                    icon: "paperplane.fill",
                                    iconColor: .pink,
                                    title: "Send Test Notification"
                                )
                            }
                        }

                        // Startup Sound
                        SettingsSectionCard {
                            Toggle(isOn: Binding(
                                get: { !UserDefaults.standard.bool(forKey: "startup_sound_disabled") },
                                set: { UserDefaults.standard.set(!$0, forKey: "startup_sound_disabled") }
                            )) {
                                SettingsRow(
                                    icon: "speaker.wave.2.fill",
                                    iconColor: .purple,
                                    title: "Startup Sound"
                                )
                            }
                            .tint(BlipColors.accentPurple)
                            .padding(.trailing, 16)
                        }

                        // Notification Settings
                        SettingsSectionCard {
                            Button {
                                #if canImport(UIKit)
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                                #else
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
                                #endif
                            } label: {
                                SettingsRow(
                                    icon: "bell.badge.fill",
                                    iconColor: .red,
                                    title: "Notification Settings",
                                    showExternalLink: true
                                )
                            }
                        }

                        // About
                        SettingsSectionCard {
                            Button { showAbout = true } label: {
                                SettingsRow(
                                    icon: "info.circle.fill",
                                    iconColor: .gray,
                                    title: "About",
                                    showChevron: true
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Version
                    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Text("Bzap \(v) (\(b))")
                        .font(BlipFonts.small)
                        .foregroundStyle(BlipColors.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
            }
            .navigationDestination(isPresented: $showWebhooks) {
                WebhooksView(secretManager: secretManager, apiClient: apiClient)
            }
            .navigationDestination(isPresented: $showSubscription) {
                SubscriptionView(trialManager: trialManager)
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showTemplates) {
                TemplatesView(secretManager: secretManager)
            }
            .sheet(isPresented: $showMonitors) {
                MonitorsView(secretManager: secretManager, apiClient: apiClient)
            }
            .sheet(isPresented: $showLinkDevice) {
                LinkDeviceView(secretManager: secretManager, apiClient: apiClient)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

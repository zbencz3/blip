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

    @State private var showWebhooks = false
    @State private var showSubscription = false
    @State private var showAbout = false
    @State private var showTemplates = false

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
                                    subtitle: "Your free access ends \(Constants.trialEndDate).",
                                    showChevron: true
                                )
                            }
                        }

                        // Webhooks
                        SettingsSectionCard {
                            Button { showWebhooks = true } label: {
                                SettingsRow(
                                    icon: "bolt.fill",
                                    iconColor: .blue,
                                    title: "Webhooks",
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
                SubscriptionView()
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showTemplates) {
                TemplatesView(secretManager: secretManager)
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

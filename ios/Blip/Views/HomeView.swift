import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @State private var showSettings = false
    @State private var showNotifications = false

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

                    Spacer().frame(height: 40)

                    // Hero
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome\nto ") + Text("bzap").foregroundColor(BlipColors.accentPurple).bold()
                    }
                    .font(BlipFonts.heroTitle)
                    .foregroundStyle(BlipColors.textPrimary)

                    Text("Make this device go **bzap** by sending a notification with the API call below.")
                        .font(BlipFonts.body)
                        .foregroundStyle(BlipColors.textSecondary)

                    // Curl snippet
                    CurlSnippetCard(command: viewModel.curlCommand) {
                        await viewModel.sendTest()
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        ActionButton(title: "Copy", icon: "doc.on.doc", style: .primary) {
                            viewModel.copyToClipboard()
                        }
                        ShareLink(item: viewModel.curlCommand) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Read docs link
                    Button {
                        // TODO: Set documentation URL when available
                    } label: {
                        Label("Read docs", systemImage: "doc.text")
                            .font(BlipFonts.body)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    .disabled(true)
                    .opacity(0.5)

                    Spacer().frame(height: 20)

                    TrialBannerView()
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(secretManager: viewModel.secretManager, apiClient: viewModel.apiClient)
        }
        .sheet(isPresented: $showNotifications) {
            RecentNotificationsView()
        }
    }
}

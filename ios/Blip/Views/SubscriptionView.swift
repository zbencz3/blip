import SwiftUI

struct SubscriptionView: View {
    @State private var selectedPlan: Plan = .monthly
    @State private var showComingSoon = false

    enum Plan {
        case monthly, yearly
    }

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Subscribe to\nkeep ") + Text("bzap").foregroundColor(BlipColors.accentPurple).bold() + Text("'ing")
                    }
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(BlipColors.textPrimary)
                    .multilineTextAlignment(.center)

                    HStack(spacing: 0) {
                        Text("Your free access ends ")
                            .foregroundStyle(BlipColors.textPrimary)
                        Text(Constants.trialEndDate)
                            .foregroundStyle(BlipColors.accentGreen)
                        Text(".")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                    .font(BlipFonts.body)

                    Text("Pick a plan before then to keep the pushes coming.")
                        .font(BlipFonts.body)
                        .foregroundStyle(BlipColors.textSecondary)
                        .multilineTextAlignment(.center)

                    // Plan cards
                    VStack(spacing: 12) {
                        planCard(
                            title: "Monthly",
                            price: "4.99/month",
                            description: "Keep the pushes coming after your free access ends.",
                            isSelected: selectedPlan == .monthly
                        ) {
                            selectedPlan = .monthly
                        }

                        planCard(
                            title: "Yearly",
                            price: "49.99/year",
                            description: "Keeps your device bzap'ing at a better price.",
                            isSelected: selectedPlan == .yearly
                        ) {
                            selectedPlan = .yearly
                        }
                    }

                    Text("Plan auto-renews for 4.99/month until cancelled.")
                        .font(BlipFonts.caption)
                        .foregroundStyle(BlipColors.textSecondary)

                    Button { showComingSoon = true } label: {
                        Text("Subscribe")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BlipColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button { showComingSoon = true } label: {
                        Text("Restore Subscription")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Manage") { showComingSoon = true }
                    Button("Redeem Code") { showComingSoon = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(BlipColors.textPrimary)
                }
            }
        }
        .alert("Coming Soon", isPresented: $showComingSoon) {
            Button("OK") {}
        } message: {
            Text("Subscriptions will be available in a future update.")
        }
    }

    private func planCard(
        title: String,
        price: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(BlipColors.textPrimary)
                        Text(price)
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? BlipColors.accentGreen : BlipColors.textSecondary)
                        .font(.system(size: 24))
                }
                Text(description)
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
            }
            .padding()
            .background(BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? BlipColors.accentGreen : BlipColors.cardBorder, lineWidth: isSelected ? 2 : 0.5)
            )
        }
    }
}

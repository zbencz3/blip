import SwiftUI
import StoreKit

struct SubscriptionView: View {
    var trialManager: TrialManager?
    @State private var subscriptionManager = SubscriptionManager()
    @State private var selectedProductID: String = SubscriptionManager.ProductIDs.monthly
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Subscribe to\nkeep ") + Text("bzap").foregroundColor(BlipColors.accentPurple).bold() + Text("'ing")
                    }
                    .font(BlipFonts.display)
                    .foregroundStyle(BlipColors.textPrimary)
                    .multilineTextAlignment(.center)

                    // Trial status
                    if subscriptionManager.isSubscribed {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BlipColors.accentGreen)
                            Text("You're subscribed!")
                                .foregroundStyle(BlipColors.accentGreen)
                        }
                        .font(BlipFonts.body)
                    } else if let trialManager {
                        HStack(spacing: 0) {
                            Text("Your free access ends ")
                                .foregroundStyle(BlipColors.textPrimary)
                            Text(trialManager.trialEndDateFormatted)
                                .foregroundStyle(BlipColors.accentGreen)
                            Text(".")
                                .foregroundStyle(BlipColors.textPrimary)
                        }
                        .font(BlipFonts.body)

                        Text("Pick a plan before then to keep the pushes coming.")
                            .font(BlipFonts.body)
                            .foregroundStyle(BlipColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Product cards
                    if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                        ProgressView()
                            .tint(BlipColors.textSecondary)
                            .padding(40)
                    } else if !subscriptionManager.products.isEmpty {
                        VStack(spacing: 12) {
                            if let monthly = subscriptionManager.monthlyProduct {
                                productCard(
                                    product: monthly,
                                    isSelected: selectedProductID == monthly.id
                                )
                            }
                            if let yearly = subscriptionManager.yearlyProduct {
                                productCard(
                                    product: yearly,
                                    isSelected: selectedProductID == yearly.id
                                )
                            }
                        }
                    } else {
                        // Fallback when StoreKit products aren't available yet
                        VStack(spacing: 12) {
                            fallbackPlanCard(
                                title: "Monthly",
                                price: "$0.99/month",
                                description: "Keep the pushes coming after your free trial ends.",
                                isSelected: selectedProductID == SubscriptionManager.ProductIDs.monthly
                            ) {
                                selectedProductID = SubscriptionManager.ProductIDs.monthly
                            }
                            fallbackPlanCard(
                                title: "Yearly",
                                price: "$9.99/year",
                                description: "Keep your device bzap'ing at a better price.",
                                isSelected: selectedProductID == SubscriptionManager.ProductIDs.yearly
                            ) {
                                selectedProductID = SubscriptionManager.ProductIDs.yearly
                            }
                        }
                    }

                    // Error
                    if let error = subscriptionManager.errorMessage {
                        Text(error)
                            .font(BlipFonts.caption)
                            .foregroundStyle(.red)
                    }

                    // Auto-renew note
                    if let selected = subscriptionManager.products.first(where: { $0.id == selectedProductID }) {
                        Text("Plan auto-renews for \(selected.displayPrice)/\(selected.subscription?.subscriptionPeriod.unit == .year ? "year" : "month") until cancelled.")
                            .font(BlipFonts.caption)
                    } else {
                        Text("Plan auto-renews until cancelled.")
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                    }

                    // Subscribe button
                    if !subscriptionManager.isSubscribed {
                        Button {
                            Task { await subscribe() }
                        } label: {
                            Group {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Subscribe")
                                }
                            }
                            .font(BlipFonts.sectionHeader)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BlipColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(subscriptionManager.isLoading)

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("Restore Subscription")
                                .font(BlipFonts.body)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Links
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: "https://zbencz3.github.io/blip/terms.html")!)
                        Link("Privacy Policy", destination: URL(string: "https://zbencz3.github.io/blip/privacy.html")!)
                    }
                    .font(BlipFonts.caption)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Manage Subscription") {
                        Task {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                try? await AppStore.showManageSubscriptions(in: windowScene)
                            }
                        }
                    }
                    Button("Redeem Code") {
                        SKPaymentQueue.default().presentCodeRedemptionSheet()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(BlipColors.textPrimary)
                }
            }
        }
    }

    private func subscribe() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else { return }
        _ = await subscriptionManager.purchase(product)
    }

    private func productCard(product: Product, isSelected: Bool) -> some View {
        Button { selectedProductID = product.id } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(BlipFonts.sectionHeader)
                            .foregroundStyle(BlipColors.textPrimary)
                        Text(product.displayPrice + "/" + (product.subscription?.subscriptionPeriod.unit == .year ? "year" : "month"))
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? BlipColors.accentGreen : BlipColors.textSecondary)
                        .font(BlipFonts.display)
                }
                Text(product.description)
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

    private func fallbackPlanCard(title: String, price: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(BlipFonts.sectionHeader)
                            .foregroundStyle(BlipColors.textPrimary)
                        Text(price)
                            .font(BlipFonts.caption)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? BlipColors.accentGreen : BlipColors.textSecondary)
                        .font(BlipFonts.display)
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

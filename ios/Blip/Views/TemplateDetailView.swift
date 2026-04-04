import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TemplateDetailView: View {
    let template: WebhookTemplate
    let webhookURL: String

    @State private var copied = false

    private var resolvedSnippet: String {
        template.curlTemplate.replacingOccurrences(of: "{{WEBHOOK_URL}}", with: webhookURL)
    }

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 14) {
                        Image(systemName: template.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(template.iconColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(BlipFonts.sectionHeader)
                                .foregroundStyle(BlipColors.textPrimary)
                            Text(template.description)
                                .font(BlipFonts.caption)
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                        Spacer()
                    }

                    // Code snippet card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(snippetLanguageLabel)
                                .font(BlipFonts.caption)
                                .foregroundStyle(BlipColors.textSecondary)
                            Spacer()
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(resolvedSnippet)
                                .font(BlipFonts.code)
                                .foregroundStyle(BlipColors.textPrimary)
                        }
                    }
                    .padding()
                    .background(BlipColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                    )

                    // Action buttons
                    HStack(spacing: 12) {
                        ActionButton(
                            title: copied ? "Copied!" : "Copy",
                            icon: copied ? "checkmark" : "doc.on.doc",
                            style: .primary
                        ) {
                            copyToClipboard()
                        }
                        ShareLink(item: resolvedSnippet) {
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
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle(template.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var snippetLanguageLabel: String {
        switch template.category {
        case .scripting:
            if template.name == "Python" { return "Python" }
            if template.name == "Node.js" { return "JavaScript" }
            return "Bash"
        default:
            return "Bash"
        }
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = resolvedSnippet
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resolvedSnippet, forType: .string)
        #endif
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }
}

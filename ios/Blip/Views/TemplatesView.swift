import SwiftUI

struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    let secretManager: SecretManager

    @State private var searchText = ""
    @State private var selectedTemplate: WebhookTemplate?

    private var filteredTemplates: [WebhookTemplate] {
        if searchText.isEmpty {
            return TemplateLibrary.all
        }
        let query = searchText.lowercased()
        return TemplateLibrary.all.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.category.rawValue.lowercased().contains(query)
        }
    }

    private var visibleCategories: [TemplateCategory] {
        TemplateCategory.allCases.filter { category in
            filteredTemplates.contains { $0.category == category }
        }
    }

    var body: some View {
        ZStack {
            BlipColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if filteredTemplates.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(BlipColors.textSecondary)
                            Text("No templates found")
                                .font(BlipFonts.body)
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(visibleCategories) { category in
                            TemplateCategorySection(
                                category: category,
                                templates: filteredTemplates.filter { $0.category == category },
                                onSelect: { selectedTemplate = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Templates")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search templates")
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(BlipColors.textPrimary)
                }
            }
        }
        .navigationDestination(item: $selectedTemplate) { template in
            TemplateDetailView(template: template, webhookURL: secretManager.webhookURL)
        }
    }
}

private struct TemplateCategorySection: View {
    let category: TemplateCategory
    let templates: [WebhookTemplate]
    let onSelect: (WebhookTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.rawValue)
                .font(BlipFonts.sectionHeader)
                .foregroundStyle(BlipColors.accentPurple)

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    Button { onSelect(template) } label: {
                        TemplateRow(template: template)
                    }
                    if index < templates.count - 1 {
                        Divider()
                            .background(BlipColors.cardBorder)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BlipColors.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

private struct TemplateRow: View {
    let template: WebhookTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(template.iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(BlipFonts.body)
                    .foregroundStyle(BlipColors.textPrimary)
                Text(template.description)
                    .font(BlipFonts.caption)
                    .foregroundStyle(BlipColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BlipColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

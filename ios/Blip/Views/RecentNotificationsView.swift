import SwiftUI
import SwiftData

struct RecentNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = NotificationHistoryViewModel()
    @State private var exportItem: ExportShareItem?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RetentionPicker(selection: Binding(
                            get: { viewModel.retention },
                            set: { viewModel.setRetention($0) }
                        ))

                        if viewModel.sections.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bell.slash")
                                    .font(.system(size: 40))
                                    .foregroundStyle(BlipColors.textSecondary)
                                Text("No notifications yet")
                                    .font(BlipFonts.body)
                                    .foregroundStyle(BlipColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }

                        ForEach(filteredSections, id: \.date) { section in
                            Text(section.date, style: .date)
                                .font(BlipFonts.sectionHeader)
                                .foregroundStyle(BlipColors.accentPurple)

                            VStack(spacing: 0) {
                                ForEach(section.notifications) { notification in
                                    NotificationRow(notification: notification)
                                    if notification.id != section.notifications.last?.id {
                                        Divider().background(BlipColors.cardBorder)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(BlipColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Recent Notifications")
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
                    HStack(spacing: 4) {
                        exportMenuButton
                        Button {
                            viewModel.showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(BlipColors.textPrimary)
                        }
                    }
                }
            }
            .alert("Delete All Notifications", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) { viewModel.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all notification history.")
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
        }
        .searchable(text: $searchText, prompt: "Search notifications")
        .preferredColorScheme(.dark)
        .onAppear { viewModel.load(context: modelContext) }
    }

    private var filteredSections: [(date: Date, notifications: [NotificationRecord])] {
        guard !searchText.isEmpty else { return viewModel.sections }
        let query = searchText.lowercased()
        return viewModel.sections.compactMap { section in
            let filtered = section.notifications.filter { record in
                (record.title?.lowercased().contains(query) ?? false) ||
                (record.message?.lowercased().contains(query) ?? false) ||
                (record.subtitle?.lowercased().contains(query) ?? false)
            }
            return filtered.isEmpty ? nil : (date: section.date, notifications: filtered)
        }
    }

    private var exportMenuButton: some View {
        Menu {
            Button("Export as JSON") {
                prepareExport(format: .json)
            }
            Button("Export as CSV") {
                prepareExport(format: .csv)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(BlipColors.textPrimary)
        }
        .disabled(viewModel.sections.isEmpty)
    }

    private func prepareExport(format: ExportFormat) {
        let allRecords = viewModel.sections.flatMap { $0.notifications }
        let content = NotificationExporter.export(allRecords, format: format)
        let ext = format == .json ? "json" : "csv"
        let filename = "blip-notifications.\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        exportItem = ExportShareItem(url: url)
    }
}

// MARK: - Helpers

private struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: View {
    let items: [Any]

    var body: some View {
        #if canImport(UIKit)
        UIShareSheetRepresentable(items: items)
        #else
        Text("Export saved to temporary directory.")
            .padding()
        #endif
    }
}

#if canImport(UIKit)
import UIKit

private struct UIShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

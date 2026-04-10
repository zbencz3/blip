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

                if viewModel.sections.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(BlipFonts.hero)
                            .foregroundStyle(BlipColors.textSecondary)
                        Text("No notifications yet")
                            .font(BlipFonts.label)
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                } else {
                    List {
                        // Retention picker
                        Section {
                            RetentionPicker(selection: Binding(
                                get: { viewModel.retention },
                                set: { viewModel.setRetention($0) }
                            ))
                        }
                        .listRowBackground(BlipColors.cardBackground)

                        ForEach(filteredSections, id: \.date) { section in
                            Section {
                                ForEach(section.notifications) { notification in
                                    NotificationRow(notification: notification)
                                }
                                .onDelete { offsets in
                                    let toDelete = offsets.map { section.notifications[$0] }
                                    withAnimation {
                                        for record in toDelete {
                                            viewModel.delete(record)
                                        }
                                    }
                                }
                            } header: {
                                Text(section.date, style: .date)
                                    .font(BlipFonts.button)
                                    .foregroundStyle(BlipColors.accentPurple)
                                    .textCase(nil)
                            }
                            .listRowBackground(BlipColors.cardBackground)
                            .listRowSeparatorTint(BlipColors.cardBorder)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
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
                    Button {
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    exportMenuButton
                }
            }
            .alert("Delete All Notifications", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) { viewModel.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all notification history.")
            }
            .sheet(item: $exportItem) { item in
                #if canImport(UIKit)
                UIShareSheetView(url: item.url)
                #endif
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
        let filename = "bzap-notifications.\(ext)"
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

#if canImport(UIKit)
import UIKit

private struct UIShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

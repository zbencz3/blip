import SwiftUI

struct MonitorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let monitor: APIClient.MonitorResponse
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large status indicator
                        VStack(spacing: 12) {
                            StatusDot(status: monitor.status)
                                .scaleEffect(3)
                                .padding(.bottom, 12)

                            Text(monitor.status.uppercased())
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(statusColor(for: monitor.status))

                            Text(monitor.name)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(BlipColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                        )

                        // Details card
                        VStack(alignment: .leading, spacing: 0) {
                            detailRow(label: "URL", value: monitor.url)
                            Divider().background(BlipColors.cardBorder)
                            detailRow(label: "INTERVAL", value: "\(monitor.interval) min")
                            Divider().background(BlipColors.cardBorder)
                            detailRow(label: "LAST CHECKED", value: lastCheckedText)
                            Divider().background(BlipColors.cardBorder)
                            detailRow(label: "FAILURES", value: "\(monitor.consecutiveFailures)")
                            Divider().background(BlipColors.cardBorder)
                            detailRow(label: "CREATED", value: createdText)
                        }
                        .background(BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                        )

                        // Delete button
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Delete Monitor")
                            }
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Monitor")
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
            }
            .alert("Delete Monitor?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will stop monitoring \(monitor.name).")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(BlipColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var lastCheckedText: String {
        guard let date = monitor.lastCheckedAt else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private var createdText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: monitor.createdAt)
    }
}

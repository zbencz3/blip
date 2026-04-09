import SwiftUI

struct MonitorsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MonitorsViewModel
    @State private var showAddMonitor = false
    @State private var selectedMonitor: APIClient.MonitorResponse?

    init(secretManager: SecretManager, apiClient: APIClient = APIClient()) {
        _viewModel = State(initialValue: MonitorsViewModel(secretManager: secretManager, apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                if viewModel.monitors.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    monitorsList
                }
            }
            .navigationTitle("Monitors")
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
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddMonitor = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(BlipColors.accentGreen)
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $showAddMonitor) {
                AddMonitorSheet { name, url, interval in
                    await viewModel.create(name: name, url: url, interval: interval)
                }
            }
            .sheet(item: $selectedMonitor) { monitor in
                MonitorDetailView(monitor: monitor) {
                    await viewModel.delete(monitor)
                    selectedMonitor = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(">_")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary.opacity(0.3))

            Text("No monitors yet")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)

            Text("Add a URL to start monitoring uptime.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary.opacity(0.6))

            Button { showAddMonitor = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Monitor")
                }
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(BlipColors.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 8)
        }
    }

    private var monitorsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.monitors) { monitor in
                    Button { selectedMonitor = monitor } label: {
                        MonitorCard(monitor: monitor)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(monitor) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// MARK: - Monitor Card

private struct MonitorCard: View {
    let monitor: APIClient.MonitorResponse

    var body: some View {
        HStack(spacing: 12) {
            // Status dot with blink
            StatusDot(status: monitor.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(monitor.name)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textPrimary)
                    .lineLimit(1)

                Text(monitor.url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                    .lineLimit(1)

                if let lastChecked = monitor.lastCheckedAt {
                    Text("checked \(lastChecked, style: .relative) ago")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(BlipColors.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            Text(monitor.status.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor(for: monitor.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(for: monitor.status).opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Status Dot

struct StatusDot: View {
    let status: String
    @State private var isBlinking = false

    var body: some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 10, height: 10)
            .opacity(isBlinking ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isBlinking
            )
            .onAppear { isBlinking = true }
    }
}

// MARK: - Helpers

func statusColor(for status: String) -> Color {
    switch status.lowercased() {
    case "up": return .green
    case "down": return .red
    default: return .orange
    }
}

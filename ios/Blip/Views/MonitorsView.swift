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
                AddMonitorSheet { params in
                    await viewModel.create(params: params)
                }
                .presentationBackground(BlipColors.background)
            }
            .sheet(item: $selectedMonitor, onDismiss: {
                Task { await viewModel.refresh() }
            }) { monitor in
                MonitorDetailView(
                    monitor: monitor,
                    secretManager: viewModel.secretManager,
                    apiClient: viewModel.apiClient
                ) {
                    await viewModel.delete(monitor)
                    selectedMonitor = nil
                } onPauseToggle: {
                    await viewModel.togglePause(monitor)
                    selectedMonitor = nil
                }
                .presentationBackground(BlipColors.background)
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
                .font(BlipFonts.title)
                .foregroundStyle(BlipColors.textSecondary)

            Text("Add a URL to start monitoring uptime.")
                .font(BlipFonts.caption)
                .foregroundStyle(BlipColors.textSecondary.opacity(0.6))

            Button { showAddMonitor = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Monitor")
                }
                .font(BlipFonts.cardTitle)
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
                // Dashboard summary
                if !viewModel.monitors.isEmpty {
                    dashboardSummary
                }

                ForEach(viewModel.monitors) { monitor in
                    MonitorCard(monitor: monitor)
                        .onTapGesture { selectedMonitor = monitor }
                        .contextMenu {
                            Button {
                                Task { await viewModel.togglePause(monitor) }
                            } label: {
                                Label(
                                    monitor.status == "paused" ? "Resume" : "Pause",
                                    systemImage: monitor.status == "paused" ? "play.fill" : "pause.fill"
                                )
                            }
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

    private var dashboardSummary: some View {
        HStack(spacing: 0) {
            summaryCell(count: viewModel.upCount, label: "UP", color: .green)
            Rectangle()
                .fill(BlipColors.cardBorder)
                .frame(width: 0.5)
            summaryCell(count: viewModel.downCount, label: "DOWN", color: .red)
            Rectangle()
                .fill(BlipColors.cardBorder)
                .frame(width: 0.5)
            summaryCell(count: viewModel.pausedCount, label: "PAUSED", color: .orange)
        }
        .frame(height: 64)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    private func summaryCell(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(count > 0 ? color : BlipColors.textSecondary.opacity(0.4))
            Text(label)
                .font(BlipFonts.micro)
                .foregroundStyle(BlipColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Monitor Card

private struct MonitorCard: View {
    let monitor: APIClient.MonitorResponse

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: monitor.status)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: monitor.isHeartbeat ? "heart.fill" : "globe")
                        .font(.system(size: 10))
                        .foregroundStyle(BlipColors.textSecondary.opacity(0.5))
                    Text(monitor.name)
                        .font(BlipFonts.cardTitle)
                        .foregroundStyle(monitor.status == "paused" ? BlipColors.textSecondary : BlipColors.textPrimary)
                        .lineLimit(1)
                }

                if !monitor.isHeartbeat {
                    Text(monitor.url)
                        .font(BlipFonts.helper)
                        .foregroundStyle(BlipColors.textSecondary)
                        .lineLimit(1)
                }

                if let lastChecked = monitor.lastCheckedAt {
                    Text("\(monitor.isHeartbeat ? "last ping" : "checked") \(lastChecked, style: .relative) ago")
                        .font(BlipFonts.tiny)
                        .foregroundStyle(BlipColors.textSecondary.opacity(0.6))
                }
            }

            Spacer()

            Text(monitor.status.uppercased())
                .font(BlipFonts.badge)
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
            .opacity(status == "paused" ? 0.4 : (isBlinking ? 0.3 : 1.0))
            .animation(
                status == "paused" ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isBlinking
            )
            .onAppear {
                if status != "paused" { isBlinking = true }
            }
    }
}

// MARK: - Helpers

func statusColor(for status: String) -> Color {
    switch status.lowercased() {
    case "up": return .green
    case "down": return .red
    case "paused": return .orange
    default: return .orange
    }
}

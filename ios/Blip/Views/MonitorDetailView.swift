import SwiftUI
import Charts

struct MonitorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let monitor: APIClient.MonitorResponse
    let secretManager: SecretManager
    let apiClient: APIClient
    let onDelete: () async -> Void
    let onPauseToggle: () async -> Void

    @State private var stats: APIClient.MonitorStatsResponse?
    @State private var checks: [APIClient.MonitorCheckResponse] = []
    @State private var incidents: [APIClient.MonitorIncidentResponse] = []
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false
    @State private var isLoading = true
    @State private var showCopied = false
    @State private var showSent = false
    @State private var statusToken: String?

    private var statusPageURL: String? {
        guard let token = statusToken else { return nil }
        return "\(Constants.baseURL)/status/\(token)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        statusHeader
                        uptimeCard
                        if monitor.isHeartbeat { heartbeatPingCard }
                        if !monitor.isHeartbeat && !checks.isEmpty { responseTimeChart }
                        if !monitor.isHeartbeat { responseTimeCard }
                        statusPageCard
                        incidentsCard
                        detailsCard
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
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
                ToolbarItem(placement: .primaryAction) {
                    Button { showEditSheet = true } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(BlipColors.textPrimary)
                    }
                }
            }
            .task { await loadData() }
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
            .sheet(isPresented: $showEditSheet, onDismiss: {
                Task { await loadData() }
            }) {
                EditMonitorSheet(
                    monitor: monitor,
                    secretManager: secretManager,
                    apiClient: apiClient
                )
                .presentationBackground(BlipColors.background)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
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

            if let duration = uptimeDuration {
                Text(duration)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    private var uptimeDuration: String? {
        guard let lastChange = monitor.lastStatusChange else { return nil }
        let interval = Date().timeIntervalSince(lastChange)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(monitor.status) for \(days)d \(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(monitor.status) for \(hours)h \(mins)m"
        } else {
            return "\(monitor.status) for \(mins)m"
        }
    }

    // MARK: - Uptime Card

    private var uptimeCard: some View {
        HStack(spacing: 0) {
            uptimeCell(label: "7 DAYS", value: stats?.uptime7d)
            Rectangle()
                .fill(BlipColors.cardBorder)
                .frame(width: 0.5)
            uptimeCell(label: "30 DAYS", value: stats?.uptime30d)
            Rectangle()
                .fill(BlipColors.cardBorder)
                .frame(width: 0.5)
            VStack(spacing: 4) {
                Text("\(stats?.totalChecks ?? 0)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(BlipColors.textPrimary)
                Text("CHECKS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 72)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    private func uptimeCell(label: String, value: Double?) -> some View {
        VStack(spacing: 4) {
            if let value {
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(value >= 99 ? .green : value >= 95 ? .orange : .red)
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary.opacity(0.4))
            }
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Response Time Chart

    private var responseTimeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RESPONSE TIME")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)

            Chart(checks) { check in
                if let date = check.checkedAt {
                    LineMark(
                        x: .value("Time", date),
                        y: .value("ms", check.responseTimeMs)
                    )
                    .foregroundStyle(BlipColors.accentGreen)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", date),
                        y: .value("ms", check.responseTimeMs)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BlipColors.accentGreen.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let ms = value.as(Int.self) {
                            Text("\(ms)ms")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(BlipColors.cardBorder)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Heartbeat Ping Card

    private var heartbeatPingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PING URL")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary)

            Text("Your service should POST or GET this URL at the expected interval.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(BlipColors.textSecondary.opacity(0.6))

            if let heartbeatUrl = monitor.heartbeatUrl {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(heartbeatUrl)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(BlipColors.accentGreen)
                        .textSelection(.enabled)
                }

                // Curl snippet
                Text("curl -X POST \(heartbeatUrl)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(BlipColors.textCode)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BlipColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = heartbeatUrl
                        #endif
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy URL")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(BlipColors.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = "curl -X POST \(heartbeatUrl)"
                        #endif
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                            Text("Copy curl")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Response Time Stats

    private var responseTimeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailRow(label: "AVG", value: stats?.avgResponseMs.map { "\($0) ms" } ?? "—")
            Divider().background(BlipColors.cardBorder)
            detailRow(label: "MIN", value: stats?.minResponseMs.map { "\($0) ms" } ?? "—")
            Divider().background(BlipColors.cardBorder)
            detailRow(label: "MAX", value: stats?.maxResponseMs.map { "\($0) ms" } ?? "—")
        }
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Status Page Card

    private var statusPageCard: some View {
        Group {
            if let statusPageURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("STATUS PAGE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(BlipColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Button {
                            if let url = URL(string: statusPageURL) {
                                #if canImport(UIKit)
                                UIApplication.shared.open(url)
                                #endif
                            }
                        } label: {
                            Text(statusPageURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(BlipColors.accentPurple)
                                .underline()
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = statusPageURL
                            #endif
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopied = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied!" : "Copy")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(BlipColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        ShareLink(item: statusPageURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    Task {
                        try? await apiClient.sendStatusPagePush(
                            secret: secretManager.currentSecret,
                            statusPageURL: statusPageURL ?? ""
                        )
                        showSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSent = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showSent ? "checkmark" : "paperplane.fill")
                        Text(showSent ? "Sent!" : "Push")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BlipColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
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
    }

    // MARK: - Incidents

    private var incidentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INCIDENTS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                Spacer()
                Text("\(incidents.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(incidents.isEmpty ? .green : .red)
            }

            if incidents.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("No incidents")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(BlipColors.textSecondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(incidents.prefix(10)) { incident in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            if let date = incident.checkedAt {
                                Text(date, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(BlipColors.textPrimary)
                            }
                            if let error = incident.error {
                                Text(error)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(BlipColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(incident.responseTimeMs)ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(BlipColors.textSecondary)
                    }
                    if incident.id != incidents.prefix(10).last?.id {
                        Divider().background(BlipColors.cardBorder)
                    }
                }
            }
        }
        .padding(16)
        .background(BlipColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !monitor.isHeartbeat {
                Button {
                    if let url = URL(string: monitor.url) {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    HStack {
                        Text("URL")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(BlipColors.textSecondary)
                        Spacer()
                        Text(monitor.url)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(BlipColors.accentPurple)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(BlipColors.accentPurple)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Divider().background(BlipColors.cardBorder)
            }
            detailRow(label: "TYPE", value: monitor.isHeartbeat ? "Heartbeat" : "HTTP \(monitor.method)")
            Divider().background(BlipColors.cardBorder)
            detailRow(label: monitor.isHeartbeat ? "EXPECTED INTERVAL" : "CHECK INTERVAL", value: "\(monitor.interval / 60) min")
            if monitor.isHeartbeat, let grace = monitor.gracePeriod {
                Divider().background(BlipColors.cardBorder)
                detailRow(label: "GRACE PERIOD", value: "\(grace / 60) min")
            }
            if let keyword = monitor.keyword, !keyword.isEmpty {
                Divider().background(BlipColors.cardBorder)
                detailRow(label: "KEYWORD", value: "\(monitor.keywordShouldExist ? "contains" : "excludes") \"\(keyword)\"")
            }
            Divider().background(BlipColors.cardBorder)
            detailRow(label: monitor.isHeartbeat ? "LAST PING" : "LAST CHECK", value: lastCheckedText)
            Divider().background(BlipColors.cardBorder)
            detailRow(label: "ALERT AFTER", value: "\(monitor.failureThreshold) failure\(monitor.failureThreshold == 1 ? "" : "s")")
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
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await onPauseToggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: monitor.status == "paused" ? "play.fill" : "pause.fill")
                    Text(monitor.status == "paused" ? "Resume Monitor" : "Pause Monitor")
                }
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(BlipColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BlipColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                )
            }

            Button { showDeleteConfirm = true } label: {
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
    }

    // MARK: - Helpers

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
        guard let date = monitor.createdAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadData() async {
        async let statsTask = apiClient.monitorStats(
            secret: secretManager.currentSecret,
            monitorId: monitor.id
        )
        async let checksTask = apiClient.monitorChecks(
            secret: secretManager.currentSecret,
            monitorId: monitor.id
        )
        async let incidentsTask = apiClient.monitorIncidents(
            secret: secretManager.currentSecret,
            monitorId: monitor.id
        )

        stats = try? await statsTask
        checks = (try? await checksTask) ?? []
        incidents = (try? await incidentsTask) ?? []
        statusToken = try? await apiClient.statusToken(secret: secretManager.currentSecret)
        isLoading = false
    }
}

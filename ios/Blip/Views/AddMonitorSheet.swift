import SwiftUI

struct AddMonitorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var interval = 5
    @State private var monitorType = "http"
    @State private var method = "HEAD"
    @State private var keyword = ""
    @State private var keywordShouldExist = true
    @State private var failureThreshold = 3
    @State private var gracePeriod = 5

    let onCreate: (APIClient.CreateMonitorParams) async -> Void

    private let intervals = [1, 5, 15]

    private var isValid: Bool {
        if monitorType == "heartbeat" {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(spacing: 8) {
                            Text("$")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.accentPurple)
                            Text("new monitor")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }

                        // Type selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TYPE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)

                            HStack(spacing: 8) {
                                typeButton(type: "http", icon: "globe", label: "HTTP Check")
                                typeButton(type: "heartbeat", icon: "heart.fill", label: "Heartbeat")
                            }
                        }

                        // Name field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NAME")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                            TextField(monitorType == "heartbeat" ? "My Cron Job" : "My API Server", text: $name)
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(BlipColors.textPrimary)
                                .padding(12)
                                .background(BlipColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                                )
                        }

                        if monitorType == "http" {
                            httpFields
                        } else {
                            heartbeatFields
                        }

                        // Interval picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text(monitorType == "heartbeat" ? "EXPECTED PING INTERVAL" : "CHECK INTERVAL")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(intervals, id: \.self) { mins in
                                    Button { interval = mins } label: {
                                        Text("\(mins) min")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(interval == mins ? .black : BlipColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(interval == mins ? BlipColors.accentGreen : BlipColors.cardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(interval == mins ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }

                        // Failure threshold
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ALERT AFTER")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)

                            HStack(spacing: 8) {
                                ForEach([1, 3, 5], id: \.self) { n in
                                    Button { failureThreshold = n } label: {
                                        Text("\(n) fail\(n == 1 ? "" : "s")")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(failureThreshold == n ? .black : BlipColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(failureThreshold == n ? BlipColors.accentGreen : BlipColors.cardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(failureThreshold == n ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }

                        Spacer().frame(height: 8)

                        // Add button
                        Button {
                            Task {
                                let monitorName = name.isEmpty ? (monitorType == "http" ? url : "Heartbeat Monitor") : name
                                let params = APIClient.CreateMonitorParams(
                                    name: monitorName,
                                    url: monitorType == "http" ? url : nil,
                                    interval: interval * 60,
                                    type: monitorType,
                                    method: method,
                                    keyword: keyword.isEmpty ? nil : keyword,
                                    keywordShouldExist: keywordShouldExist,
                                    failureThreshold: failureThreshold,
                                    gracePeriod: monitorType == "heartbeat" ? gracePeriod * 60 : nil
                                )
                                await onCreate(params)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Monitor")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? BlipColors.accentGreen : BlipColors.accentGreen.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!isValid)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Add Monitor")
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - HTTP Fields

    private var httpFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            // URL
            VStack(alignment: .leading, spacing: 6) {
                Text("URL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                TextField("https://example.com/health", text: $url)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(BlipColors.textPrimary)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(BlipColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                    )
            }

            // Method
            VStack(alignment: .leading, spacing: 6) {
                Text("METHOD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                HStack(spacing: 8) {
                    ForEach(["HEAD", "GET"], id: \.self) { m in
                        Button { method = m } label: {
                            Text(m)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(method == m ? .black : BlipColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(method == m ? BlipColors.accentGreen : BlipColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(method == m ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }

            // Keyword (only for GET)
            if method == "GET" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KEYWORD CHECK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(BlipColors.textSecondary)
                    TextField("optional — e.g. \"ok\" or \"healthy\"", text: $keyword)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(BlipColors.textPrimary)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(BlipColors.cardBorder, lineWidth: 0.5)
                        )

                    if !keyword.isEmpty {
                        HStack(spacing: 8) {
                            Button { keywordShouldExist = true } label: {
                                Text("Must contain")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(keywordShouldExist ? .black : BlipColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(keywordShouldExist ? BlipColors.accentGreen : BlipColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Button { keywordShouldExist = false } label: {
                                Text("Must NOT contain")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(!keywordShouldExist ? .black : BlipColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(!keywordShouldExist ? Color.red.opacity(0.8) : BlipColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Heartbeat Fields

    private var heartbeatFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(BlipColors.accentPurple)
                Text("Your service pings Bzap at a regular interval. If it stops, you get alerted.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
            }
            .padding(12)
            .background(BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(BlipColors.cardBorder, lineWidth: 0.5)
            )

            // Grace period
            VStack(alignment: .leading, spacing: 6) {
                Text("GRACE PERIOD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary)
                Text("Extra wait time after expected interval before alerting.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColors.textSecondary.opacity(0.6))

                HStack(spacing: 8) {
                    ForEach([1, 5, 15], id: \.self) { mins in
                        Button { gracePeriod = mins } label: {
                            Text("\(mins) min")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(gracePeriod == mins ? .black : BlipColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(gracePeriod == mins ? BlipColors.accentGreen : BlipColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(gracePeriod == mins ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Type Button

    private func typeButton(type: String, icon: String, label: String) -> some View {
        Button { monitorType = type } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(monitorType == type ? .black : BlipColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(monitorType == type ? BlipColors.accentPurple : BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(monitorType == type ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

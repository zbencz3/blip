import SwiftUI

struct EditMonitorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let monitor: APIClient.MonitorResponse
    let secretManager: SecretManager
    let apiClient: APIClient

    @State private var name: String
    @State private var url: String
    @State private var interval: Int
    @State private var method: String
    @State private var keyword: String
    @State private var keywordShouldExist: Bool
    @State private var failureThreshold: Int
    @State private var gracePeriod: Int
    @State private var isSaving = false
    @State private var error: String?

    private let intervals = [1, 5, 15]

    init(monitor: APIClient.MonitorResponse, secretManager: SecretManager, apiClient: APIClient) {
        self.monitor = monitor
        self.secretManager = secretManager
        self.apiClient = apiClient
        _name = State(initialValue: monitor.name)
        _url = State(initialValue: monitor.url)
        _interval = State(initialValue: monitor.interval / 60)
        _method = State(initialValue: monitor.method)
        _keyword = State(initialValue: monitor.keyword ?? "")
        _keywordShouldExist = State(initialValue: monitor.keywordShouldExist)
        _failureThreshold = State(initialValue: monitor.failureThreshold)
        _gracePeriod = State(initialValue: (monitor.gracePeriod ?? monitor.interval) / 60)
    }

    private var isValid: Bool {
        if monitor.isHeartbeat {
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
                        HStack(spacing: 8) {
                            Text("$")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.accentPurple)
                            Text("edit monitor")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }

                        // Type (read-only)
                        HStack(spacing: 8) {
                            Image(systemName: monitor.isHeartbeat ? "heart.fill" : "globe")
                                .foregroundStyle(BlipColors.accentPurple)
                            Text(monitor.isHeartbeat ? "Heartbeat Monitor" : "HTTP Monitor")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                        }

                        // Name
                        fieldLabel("NAME")
                        inputField("Monitor name", text: $name)

                        if !monitor.isHeartbeat {
                            fieldLabel("URL")
                            inputField("https://example.com/health", text: $url, keyboard: true)

                            fieldLabel("METHOD")
                            segmentedPicker(["HEAD", "GET"], selection: $method)

                            if method == "GET" {
                                fieldLabel("KEYWORD CHECK")
                                inputField("optional keyword", text: $keyword)
                            }
                        } else {
                            fieldLabel("GRACE PERIOD")
                            segmentedPicker(intervals, selection: $gracePeriod, format: { "\($0) min" })
                        }

                        fieldLabel(monitor.isHeartbeat ? "EXPECTED PING INTERVAL" : "CHECK INTERVAL")
                        segmentedPicker(intervals, selection: $interval, format: { "\($0) min" })

                        fieldLabel("ALERT AFTER")
                        segmentedPicker([1, 3, 5], selection: $failureThreshold, format: { "\($0) fail\($0 == 1 ? "" : "s")" })

                        if let error {
                            Text(error)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.red)
                        }

                        Spacer().frame(height: 8)

                        Button {
                            Task { await save() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Save Changes")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? BlipColors.accentGreen : BlipColors.accentGreen.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!isValid || isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Edit Monitor")
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

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(BlipColors.textSecondary)
    }

    private func inputField(_ placeholder: String, text: Binding<String>, keyboard: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(BlipColors.textPrimary)
            #if os(iOS)
            .keyboardType(keyboard ? .URL : .default)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
            .padding(12)
            .background(BlipColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BlipColors.cardBorder, lineWidth: 0.5))
    }

    private func segmentedPicker(_ options: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button { selection.wrappedValue = opt } label: {
                    Text(opt)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selection.wrappedValue == opt ? .black : BlipColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == opt ? BlipColors.accentGreen : BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == opt ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5))
                }
            }
        }
    }

    private func segmentedPicker(_ options: [Int], selection: Binding<Int>, format: @escaping (Int) -> String) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button { selection.wrappedValue = opt } label: {
                    Text(format(opt))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selection.wrappedValue == opt ? .black : BlipColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == opt ? BlipColors.accentGreen : BlipColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == opt ? Color.clear : BlipColors.cardBorder, lineWidth: 0.5))
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let monitorName = name.isEmpty ? url : name
            let params = APIClient.CreateMonitorParams(
                name: monitorName,
                url: monitor.isHeartbeat ? nil : url,
                interval: interval * 60,
                type: monitor.type,
                method: method,
                keyword: keyword.isEmpty ? nil : keyword,
                keywordShouldExist: keywordShouldExist,
                failureThreshold: failureThreshold,
                gracePeriod: monitor.isHeartbeat ? gracePeriod * 60 : nil
            )
            _ = try await apiClient.updateMonitor(
                secret: secretManager.currentSecret,
                monitorId: monitor.id,
                params: params
            )
            dismiss()
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}

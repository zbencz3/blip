import SwiftUI

struct AddMonitorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var interval = 5

    let onCreate: (String, String, Int) async -> Void

    private let intervals = [1, 5, 15]

    private var isValid: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                        // Name field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NAME")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)
                            TextField("My API Server", text: $name)
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

                        // URL field
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

                        // Interval picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CHECK INTERVAL")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(BlipColors.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(intervals, id: \.self) { mins in
                                    Button {
                                        interval = mins
                                    } label: {
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

                        Spacer().frame(height: 8)

                        // Add button
                        Button {
                            Task {
                                let monitorName = name.isEmpty ? url : name
                                await onCreate(monitorName, url, interval * 60)
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
}

import Foundation

@MainActor
@Observable
final class MonitorsViewModel {
    let secretManager: SecretManager
    let apiClient: APIClient

    var monitors: [APIClient.MonitorResponse] = []
    var isLoading = false
    var error: String?

    var upCount: Int { monitors.filter { $0.status == "up" }.count }
    var downCount: Int { monitors.filter { $0.status == "down" }.count }
    var pausedCount: Int { monitors.filter { $0.status == "paused" }.count }

    init(secretManager: SecretManager, apiClient: APIClient = APIClient()) {
        self.secretManager = secretManager
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            monitors = try await apiClient.listMonitors(secret: secretManager.currentSecret)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func create(name: String, url: String, interval: Int) async {
        do {
            let monitor = try await apiClient.createMonitor(
                secret: secretManager.currentSecret,
                name: name,
                url: url,
                interval: interval
            )
            monitors.append(monitor)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ monitor: APIClient.MonitorResponse) async {
        do {
            try await apiClient.deleteMonitor(
                secret: secretManager.currentSecret,
                monitorId: monitor.id
            )
            monitors.removeAll { $0.id == monitor.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePause(_ monitor: APIClient.MonitorResponse) async {
        let shouldPause = monitor.status != "paused"
        do {
            let updated = try await apiClient.pauseMonitor(
                secret: secretManager.currentSecret,
                monitorId: monitor.id,
                paused: shouldPause
            )
            if let index = monitors.firstIndex(where: { $0.id == monitor.id }) {
                monitors[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }
}

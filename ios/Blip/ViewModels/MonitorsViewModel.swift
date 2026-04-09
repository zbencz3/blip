import Foundation

@MainActor
@Observable
final class MonitorsViewModel {
    let secretManager: SecretManager
    let apiClient: APIClient

    var monitors: [APIClient.MonitorResponse] = []
    var isLoading = false
    var error: String?

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

    func refresh() async {
        await load()
    }
}

import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class WebhooksViewModel {
    let secretManager: SecretManager
    let apiClient: APIClient

    var devices: [Device] = []
    var isLoading = false
    var currentDeviceToken: String?

    init(secretManager: SecretManager, apiClient: APIClient = APIClient()) {
        self.secretManager = secretManager
        self.apiClient = apiClient
    }

    var mainWebhookURL: String {
        secretManager.webhookURL
    }

    var mainCurlCommand: String {
        secretManager.curlCommand
    }

    var lastWebhookUsed: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lastWebhookUsed) as? Date else {
            return nil
        }
        return timestamp
    }

    func loadDevices() async {
        isLoading = true
        defer { isLoading = false }
        currentDeviceToken = UserDefaults.standard.string(forKey: "device_token")
        do {
            devices = try await apiClient.listDevices(secret: secretManager.currentSecret)
        } catch {}
    }

    func isCurrentDevice(_ device: Device) -> Bool {
        device.deviceToken == currentDeviceToken
    }

    func copyMainWebhook() {
        copyString(mainCurlCommand)
    }

    func copyDeviceWebhook(_ device: Device) {
        guard let command = device.curlCommand else { return }
        copyString(command)
    }

    private func copyString(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}

import Foundation

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
@Observable
final class HomeViewModel {
    let secretManager: SecretManager
    let apiClient: APIClient

    var showCopied = false

    init(secretManager: SecretManager, apiClient: APIClient = APIClient()) {
        self.secretManager = secretManager
        self.apiClient = apiClient
    }

    var curlCommand: String {
        secretManager.curlCommand
    }

    var webhookURL: String {
        secretManager.webhookURL
    }

    func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = curlCommand
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curlCommand, forType: .string)
        #endif
        showCopied = true
    }

    func sendTest() async {
        try? await apiClient.sendTest(secret: secretManager.currentSecret)
    }
}

import Foundation

@MainActor
@Observable
final class SecretManager {
    private let keychain: KeychainService

    private(set) var currentSecret: String

    var webhookURL: String {
        "\(Constants.apiBaseURL)/\(currentSecret)"
    }

    var curlCommand: String {
        "curl -X POST \(webhookURL) \\\n  -d 'Hello world! 🚀'"
    }

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
        if let existing = keychain.load(key: Constants.Keychain.secretKey) {
            self.currentSecret = existing
        } else {
            let secret = SecretManager.generateSecret()
            do {
                try keychain.save(secret, for: Constants.Keychain.secretKey)
            } catch {
                print("[SecretManager] Warning: failed to save secret to keychain: \(error). Using in-session secret.")
            }
            self.currentSecret = secret
        }
    }

    func rotate(using apiClient: APIClient) async throws {
        let response = try await apiClient.rotateSecret(currentSecret: currentSecret)
        try keychain.save(response.secret, for: Constants.Keychain.secretKey)
        currentSecret = response.secret
    }

    nonisolated static func generateSecret() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "blp_usr_\(hex)"
    }
}

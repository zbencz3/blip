import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
}

struct KeychainService {
    let service: String

    init(service: String = Constants.Keychain.service) {
        self.service = service
    }

    func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)

        // Delete any existing item (both local-only and synced) to avoid conflicts
        delete(key: key)

        // Save with iCloud Keychain sync enabled
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    func load(key: String) -> String? {
        // Search both synced and local items
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        // Delete local-only items
        let localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: false
        ]
        SecItemDelete(localQuery as CFDictionary)

        // Delete synced items
        let syncQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(syncQuery as CFDictionary)
    }

    /// Migrate old local-only keychain items to iCloud-synced items.
    /// Call once on app launch.
    func migrateToSynced(key: String) {
        // Check if a local-only item exists
        let localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: false
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(localQuery as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return // No local-only item to migrate
        }

        // Re-save as synced (save() handles delete + add)
        try? save(value, for: key)
    }
}

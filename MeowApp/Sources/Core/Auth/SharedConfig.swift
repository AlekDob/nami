import Foundation
import Security

enum SharedConfig {
    static let appGroupID = "group.com.alekdob.MeowApp"
    static let keychainService = "com.meow.apikey"
    static let serverURLKey = "com.meow.serverurl"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var serverURL: String {
        get {
            if let url = sharedDefaults.string(forKey: serverURLKey),
               !url.isEmpty {
                return url
            }
            // Fallback: read from standard UserDefaults (legacy)
            if let legacy = UserDefaults.standard.string(forKey: serverURLKey),
               !legacy.isEmpty {
                // Auto-migrate to shared
                sharedDefaults.set(legacy, forKey: serverURLKey)
                return legacy
            }
            return ""
        }
        set {
            sharedDefaults.set(newValue, forKey: serverURLKey)
            // Keep standard in sync for backward compat
            UserDefaults.standard.set(newValue, forKey: serverURLKey)
        }
    }

    static var apiKey: String {
        readKeychain(service: keychainService) ?? ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty && !serverURL.isEmpty
    }

    // MARK: - Keychain (with access group)

    static func saveKeychain(service: String, value: String) {
        let data = Data(value.utf8)
        deleteKeychain(service: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: appGroupID,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func readKeychain(service: String) -> String? {
        // Try with access group first
        if let value = readKeychainWith(
            service: service, accessGroup: appGroupID
        ) {
            return value
        }
        // Fallback: read legacy item without access group
        if let value = readKeychainWith(
            service: service, accessGroup: nil
        ) {
            // Migrate to shared access group
            saveKeychain(service: service, value: value)
            deleteKeychainLegacy(service: service)
            return value
        }
        return nil
    }

    static func deleteKeychain(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: appGroupID
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    private static func readKeychainWith(
        service: String, accessGroup: String?
    ) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychainLegacy(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

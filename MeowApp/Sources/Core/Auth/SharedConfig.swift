import Foundation
import Security

enum SharedConfig {
    static let appGroupID = "group.com.alekdob.MeowApp"
    static let keychainService = "com.meow.apikey"
    static let serverURLKey = "com.meow.serverurl"
    static let apiKeyDefaultsKey = "com.meow.apikey.shared"
    static let elevenLabsAPIKeyKey = "com.meow.elevenlabs.apikey"

    // MARK: - Shared UserDefaults

    static var sharedDefaults: UserDefaults {
        let ud = UserDefaults(suiteName: appGroupID)
        if ud == nil {
            print("[SharedConfig] WARNING: App Group '\(appGroupID)' UserDefaults returned nil!")
        }
        return ud ?? .standard
    }

    // MARK: - Server URL

    static var serverURL: String {
        get {
            if let url = sharedDefaults.string(forKey: serverURLKey),
               !url.isEmpty {
                return url
            }
            if let url = UserDefaults.standard.string(
                forKey: serverURLKey
            ), !url.isEmpty {
                return url
            }
            return ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: serverURLKey)
            sharedDefaults.set(newValue, forKey: serverURLKey)
        }
    }

    // MARK: - API Key
    // Primary: shared UserDefaults (works across app + extension)
    // Fallback: Keychain (main app only)

    static var apiKey: String {
        if let key = sharedDefaults.string(forKey: apiKeyDefaultsKey),
           !key.isEmpty {
            print("[SharedConfig] apiKey found in sharedDefaults")
            return key
        }
        let kcKey = readKeychain(service: keychainService)
        print("[SharedConfig] apiKey from sharedDefaults: nil, keychain: \(kcKey != nil ? "found" : "nil")")
        return kcKey ?? ""
    }

    static var isConfigured: Bool {
        let url = serverURL
        let key = apiKey
        let result = !key.isEmpty && !url.isEmpty
        print("[SharedConfig] isConfigured=\(result) url='\(url.prefix(30))...' apiKey=\(key.isEmpty ? "EMPTY" : "SET(\(key.count)chars)")")
        return result
    }

    // Saves to BOTH shared UserDefaults and Keychain
    static func saveAPIKey(_ value: String) {
        print("[SharedConfig] saveAPIKey called, length=\(value.count)")
        sharedDefaults.set(value, forKey: apiKeyDefaultsKey)
        sharedDefaults.synchronize()
        // Verify write
        let verify = sharedDefaults.string(forKey: apiKeyDefaultsKey)
        print("[SharedConfig] saveAPIKey verify: \(verify != nil ? "OK" : "FAILED")")
        saveKeychain(service: keychainService, value: value)
    }

    static func deleteAPIKey() {
        sharedDefaults.removeObject(forKey: apiKeyDefaultsKey)
        deleteKeychain(service: keychainService)
    }

    // MARK: - ElevenLabs API Key

    static var elevenLabsAPIKey: String {
        get {
            let saved = sharedDefaults.string(forKey: elevenLabsAPIKeyKey) ?? ""
            // Return saved key or default if empty
            return saved.isEmpty ? "sk_a7193c2566c6bdc07813f7e82e7daff3855678534e3bf66d" : saved
        }
        set {
            sharedDefaults.set(newValue, forKey: elevenLabsAPIKeyKey)
        }
    }

    // MARK: - Keychain (kept for main app compatibility)

    static func saveKeychain(service: String, value: String) {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func deleteKeychain(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    static func readKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary, &result
        )
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

import Foundation
import Security
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

@MainActor
@Observable
final class AuthManager {
    var isAuthenticated = false
    var isBiometricAvailable = false
    var biometricEnabled = false

    private let biometricKey = "com.meow.biometric"

    init() {
        syncToSharedStorage()
        checkBiometricAvailability()
        biometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)
    }

    // MARK: - API Key (delegates to SharedConfig)

    var apiKey: String {
        get { SharedConfig.apiKey }
        set { SharedConfig.saveAPIKey(newValue) }
    }

    var serverURL: String {
        get { SharedConfig.serverURL }
        set { SharedConfig.serverURL = newValue }
    }

    var isConfigured: Bool {
        SharedConfig.isConfigured
    }

    // MARK: - Biometric Auth

    func authenticateWithBiometrics() async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        ) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Meow"
            )
            isAuthenticated = success
            return success
        } catch {
            return false
        }
        #else
        return true
        #endif
    }

    func setBiometricEnabled(_ enabled: Bool) {
        biometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: biometricKey)
    }

    func skipAuth() {
        isAuthenticated = true
    }

    // MARK: - Migration

    // Always sync credentials to shared storage on every launch
    // so the Share Extension can access them
    private func syncToSharedStorage() {
        print("[Auth] syncToSharedStorage starting...")

        // Sync server URL
        let url = UserDefaults.standard.string(
            forKey: SharedConfig.serverURLKey
        ) ?? ""
        if !url.isEmpty {
            SharedConfig.serverURL = url
            print("[Auth] synced serverURL='\(url.prefix(30))...'")
        }

        // Sync API key from Keychain → shared UserDefaults
        if let key = SharedConfig.readKeychain(
            service: SharedConfig.keychainService
        ), !key.isEmpty {
            SharedConfig.saveAPIKey(key)
            print("[Auth] synced apiKey to shared (\(key.count) chars)")
        } else {
            print("[Auth] WARNING: no apiKey in Keychain!")
        }

        // Verify
        let sharedURL = SharedConfig.sharedDefaults.string(
            forKey: SharedConfig.serverURLKey
        )
        let sharedKey = SharedConfig.sharedDefaults.string(
            forKey: SharedConfig.apiKeyDefaultsKey
        )
        print("[Auth] verify shared: url='\(sharedURL ?? "nil")' apiKey=\(sharedKey != nil ? "SET" : "NIL")")
    }

    // MARK: - Biometric Check

    private func checkBiometricAvailability() {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        #else
        isBiometricAvailable = false
        #endif
    }
}

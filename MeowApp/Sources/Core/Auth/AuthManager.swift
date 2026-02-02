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
        migrateServerURLIfNeeded()
        checkBiometricAvailability()
        biometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)
    }

    // MARK: - API Key (delegates to SharedConfig)

    var apiKey: String {
        get { SharedConfig.apiKey }
        set { SharedConfig.saveKeychain(
            service: SharedConfig.keychainService, value: newValue
        ) }
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

    private func migrateServerURLIfNeeded() {
        let legacyKey = "com.meow.serverurl"
        if let legacyURL = UserDefaults.standard.string(forKey: legacyKey),
           !legacyURL.isEmpty,
           SharedConfig.sharedDefaults.string(
               forKey: SharedConfig.serverURLKey
           ) == nil
        {
            SharedConfig.serverURL = legacyURL
        }
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

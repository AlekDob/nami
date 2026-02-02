import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class PushNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var isPermissionGranted = false
    var deviceToken: String?

    private let apiClient: MeowAPIClient

    init(apiClient: MeowAPIClient) {
        self.apiClient = apiClient
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isPermissionGranted = granted
            print("[Push] Permission granted: \(granted)")
            if granted { registerForRemoteNotifications() }
        } catch {
            print("[Push] Permission error: \(error)")
            isPermissionGranted = false
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = hex
        print("[Push] Got device token: \(hex)")
        // Always re-register — token may change between builds
        Task { await registerWithServer(hex) }
    }

    func handleRegistrationError(_ error: Error) {
        print("[Push] Registration failed: \(error.localizedDescription)")
        deviceToken = nil
    }

    // MARK: - UNUserNotificationCenterDelegate
    // Use non-async overloads to avoid nonisolated + @MainActor conflict

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let title = response.notification.request.content.title
        DispatchQueue.main.async {
            print("[Push] Notification tapped: \(title)")
        }
        completionHandler()
    }

    // MARK: - Private

    private func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    private func registerWithServer(_ token: String) async {
        print("[Push] Registering device token with server: \(token.prefix(8))...")
        do {
            let response = try await apiClient.registerDevice(token: token)
            print("[Push] Device registered successfully: \(response)")
        } catch {
            print("[Push] Failed to register device: \(error)")
        }
    }
}

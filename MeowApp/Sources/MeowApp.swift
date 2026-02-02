import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var pushManager: PushNotificationManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let fromPush = launchOptions?[.remoteNotification] != nil
        print("[App] didFinishLaunching fromPush=\(fromPush)")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            pushManager?.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            pushManager?.handleRegistrationError(error)
        }
    }
}
#endif

@main
struct MeowApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var authManager = AuthManager()
    @State private var wsManager = WebSocketManager()
    @State private var pushManager: PushNotificationManager?
    @State private var isReady = false
    private let apiClient = MeowAPIClient()
    private let modelContainer: ModelContainer

    init() {
        print("[App] init — creating ModelContainer")
        let schema = Schema([
            CachedMemoryEntry.self,
            CachedFileContent.self,
            CachedChatMessage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            print("[App] ModelContainer created OK")
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .task { await configureServices() }
        }
        .modelContainer(modelContainer)
    }

    @ViewBuilder
    private var rootView: some View {
        if !isReady {
            // Show a loading splash while services configure
            VStack(spacing: MeowTheme.spacingLG) {
                ASCIICatView(mood: .idle, size: .large)
                Text("meow")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(MeowTheme.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.colorInvert())
        } else if authManager.biometricEnabled && !authManager.isAuthenticated {
            lockScreen
        } else {
            ContentView(apiClient: apiClient, wsManager: wsManager, authManager: authManager)
        }
    }

    private var lockScreen: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .sleeping, size: .large)
            Text("meow")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(MeowTheme.accent)
            Text("Unlock to continue")
                .foregroundColor(.secondary)
            GlowButton("Unlock", icon: "faceid", color: MeowTheme.accent) {
                Task { await unlock() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { Task { await unlock() } }
    }

    private func unlock() async {
        let success = await authManager.authenticateWithBiometrics()
        if !success {
            authManager.skipAuth()
        }
    }

    private func configureServices() async {
        print("[App] configureServices START")
        let url = authManager.serverURL
        let key = authManager.apiKey

        print("[App] url=\(url.prefix(30)), key=\(key.isEmpty ? "EMPTY" : "SET")")

        if !url.isEmpty && !key.isEmpty {
            await apiClient.configure(baseURL: url, apiKey: key)
            wsManager.configure(baseURL: url, apiKey: key)
            wsManager.connect()
        }

        if !authManager.biometricEnabled {
            authManager.skipAuth()
        }

        // Mark ready BEFORE push (push permission dialog can block)
        print("[App] marking isReady = true")
        isReady = true

        // Initialize push notifications (non-blocking for UI)
        print("[App] initializing push...")
        let push = PushNotificationManager(apiClient: apiClient)
        pushManager = push
        #if canImport(UIKit)
        appDelegate.pushManager = push
        #endif
        await push.requestPermission()
        print("[App] push ready, token: \(push.deviceToken ?? "nil")")

        // Drain any pending shares from the offline queue
        await drainPendingShares()
    }

    private func drainPendingShares() async {
        let pending = PendingShareQueue.dequeueAll()
        guard !pending.isEmpty else { return }
        print("[App] draining \(pending.count) pending shares")
        for share in pending {
            let messages = [ChatMessage(role: .user, content: share.message)]
            do {
                _ = try await apiClient.sendChat(messages: messages)
                print("[App] sent pending share \(share.id)")
            } catch {
                // Re-queue failed items
                PendingShareQueue.enqueue(message: share.message)
                print("[App] failed to send share \(share.id): \(error)")
                break
            }
        }
    }
}

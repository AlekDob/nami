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
            print("[App] ModelContainer migration failed: \(error). Deleting old store...")
            let url = config.url
            let related = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in related { try? FileManager.default.removeItem(at: file) }
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [config])
                print("[App] ModelContainer recreated OK after purge")
            } catch {
                fatalError("Failed to create model container after purge: \(error)")
            }
        }
    }

    @State private var pendingShareContent: String?

    var body: some Scene {
        WindowGroup {
            rootView
                .task { await configureServices() }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        print("[App] handleDeepLink: \(url)")
        guard url.scheme == "meow" else { return }

        if url.host == "share" {
            // Read pending share from shared storage
            if let content = SharedConfig.sharedDefaults.string(
                forKey: "com.meow.pendingShare"
            ), !content.isEmpty {
                print("[App] found pending share: \(content.prefix(100))...")
                pendingShareContent = content
                // Clear after reading
                SharedConfig.sharedDefaults.removeObject(forKey: "com.meow.pendingShare")
                // Post notification for ChatViewModel to pick up
                NotificationCenter.default.post(
                    name: Notification.Name("pendingShareReceived"),
                    object: content
                )
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if !isReady {
            splashScreen
        } else if authManager.biometricEnabled && !authManager.isAuthenticated {
            lockScreen
        } else {
            ContentView(apiClient: apiClient, wsManager: wsManager, authManager: authManager)
        }
    }

    private var splashScreen: some View {
        ZStack {
            MeshGradientBackground()
            VStack(spacing: MeowTheme.spacingMD) {
                Image(systemName: "cat.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                Text("meow")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            MeshGradientBackground()
            VStack(spacing: MeowTheme.spacingLG) {
                Image(systemName: "cat.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                Text("meow")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text("Unlock to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                GlowButton("Unlock", icon: "faceid", color: MeowTheme.green) {
                    Task { await unlock() }
                }
            }
        }
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

        print("[App] marking isReady = true")
        isReady = true

        print("[App] initializing push...")
        let push = PushNotificationManager(apiClient: apiClient)
        pushManager = push
        #if canImport(UIKit)
        appDelegate.pushManager = push
        #endif
        await push.requestPermission()
        print("[App] push ready, token: \(push.deviceToken ?? "nil")")

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
                PendingShareQueue.enqueue(message: share.message)
                print("[App] failed to send share \(share.id): \(error)")
                break
            }
        }
    }
}

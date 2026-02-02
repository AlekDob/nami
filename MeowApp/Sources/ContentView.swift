import SwiftUI
import SwiftData

struct ContentView: View {
    let apiClient: MeowAPIClient
    let wsManager: WebSocketManager
    let authManager: AuthManager

    @State private var selectedTab: AppTab = .chat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    enum AppTab: String, CaseIterable {
        case chat = "Chat"
        case memory = "Memory"
        case jobs = "Jobs"
        case soul = "Soul"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .memory: return "brain"
            case .jobs: return "clock.arrow.circlepath"
            case .soul: return "heart.text.square"
            case .settings: return "gearshape"
            }
        }
    }

    // MARK: - ViewModels

    @State private var chatVM: ChatViewModel?
    @State private var memoryVM: MemoryViewModel?
    @State private var jobsVM: JobsViewModel?
    @State private var soulVM: SoulViewModel?
    @State private var settingsVM: SettingsViewModel?

    var body: some View {
        Group {
            #if os(macOS)
            splitViewLayout
            #else
            tabViewLayout
            #endif
        }
        .onAppear { initializeViewModels() }
    }

    // MARK: - iOS TabView

    private var tabViewLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(MeowTheme.accent)
    }

    // MARK: - macOS SplitView

    #if os(macOS)
    private var splitViewLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationTitle("meow")
        } detail: {
            tabContent(for: selectedTab)
        }
    }
    #endif

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .chat:
            if let vm = chatVM {
                ChatView(viewModel: vm)
            } else {
                loadingPlaceholder
            }
        case .memory:
            if let vm = memoryVM {
                MemoryBrowserView(viewModel: vm)
            } else {
                loadingPlaceholder
            }
        case .jobs:
            if let vm = jobsVM {
                JobsListView(viewModel: vm)
            } else {
                loadingPlaceholder
            }
        case .soul:
            if let vm = soulVM {
                SoulView(viewModel: vm)
            } else {
                loadingPlaceholder
            }
        case .settings:
            if let vm = settingsVM {
                SettingsView(viewModel: vm, wsManager: wsManager)
            } else {
                loadingPlaceholder
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: MeowTheme.spacingMD) {
            ASCIICatView(mood: .thinking, size: .medium)
            Text("Loading...")
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor)
    }

    // MARK: - Initialization

    private func initializeViewModels() {
        let chat = ChatViewModel(apiClient: apiClient, wsManager: wsManager)
        chat.setModelContext(modelContext)
        chatVM = chat
        memoryVM = MemoryViewModel(apiClient: apiClient)
        jobsVM = JobsViewModel(apiClient: apiClient)
        soulVM = SoulViewModel(apiClient: apiClient)
        settingsVM = SettingsViewModel(authManager: authManager, apiClient: apiClient, wsManager: wsManager)
    }

    // MARK: - Colors

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }
}

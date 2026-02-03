import SwiftUI
import SwiftData

struct ContentView: View {
    let apiClient: MeowAPIClient
    let wsManager: WebSocketManager
    let authManager: AuthManager

    @State private var selectedTab: AppTab = .chat
    @State private var showSidebar = false
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
            sidebarLayout
            #endif
        }
        .onAppear { initializeViewModels() }
    }

    // MARK: - iOS Sidebar Layout

    #if os(iOS)
    private var sidebarLayout: some View {
        ZStack(alignment: .leading) {
            // Main content
            mainContent
                .offset(x: showSidebar ? 280 : 0)

            // Dimming overlay
            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .offset(x: showSidebar ? 280 : 0)
                    .onTapGesture { closeSidebar() }
            }

            // Sidebar drawer
            if showSidebar {
                sidebarDrawer
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 && !showSidebar {
                        openSidebar()
                    } else if value.translation.width < -80 && showSidebar {
                        closeSidebar()
                    }
                }
        )
    }

    private var sidebarDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Meow")
                .font(.title2.bold())
                .foregroundColor(primaryColor)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 24)

            // Menu items
            ForEach(AppTab.allCases, id: \.self) { tab in
                sidebarRow(tab)
            }

            Spacer()
        }
        .frame(width: 280)
        .background(surfaceColor)
    }

    private func sidebarRow(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
            closeSidebar()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tab.icon)
                    .font(.body)
                    .foregroundColor(
                        selectedTab == tab ? primaryColor : mutedColor
                    )
                    .frame(width: 24)
                Text(tab.rawValue)
                    .font(.body)
                    .foregroundColor(
                        selectedTab == tab ? primaryColor : secondaryColor
                    )
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                selectedTab == tab
                    ? (colorScheme == .dark
                        ? MeowTheme.Dark.surfaceHover
                        : MeowTheme.Light.surfaceHover)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }

    private var mainContent: some View {
        NavigationStack {
            tabContent(for: selectedTab)
        }
    }

    private func openSidebar() {
        showSidebar = true
    }

    private func closeSidebar() {
        showSidebar = false
    }
    #endif

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
                ChatView(
                    viewModel: vm,
                    onMenuTap: { openSidebarIfAvailable() }
                )
            } else {
                loadingPlaceholder
            }
        case .memory:
            if let vm = memoryVM {
                MemoryBrowserView(
                    viewModel: vm,
                    onMenuTap: { openSidebarIfAvailable() }
                )
            } else {
                loadingPlaceholder
            }
        case .jobs:
            if let vm = jobsVM {
                JobsListView(
                    viewModel: vm,
                    onMenuTap: { openSidebarIfAvailable() }
                )
            } else {
                loadingPlaceholder
            }
        case .soul:
            if let vm = soulVM {
                SoulView(
                    viewModel: vm,
                    onMenuTap: { openSidebarIfAvailable() }
                )
            } else {
                loadingPlaceholder
            }
        case .settings:
            if let vm = settingsVM {
                SettingsView(
                    viewModel: vm,
                    wsManager: wsManager,
                    onMenuTap: { openSidebarIfAvailable() }
                )
            } else {
                loadingPlaceholder
            }
        }
    }

    private func openSidebarIfAvailable() {
        #if os(iOS)
        openSidebar()
        #endif
    }

    private var loadingPlaceholder: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: MeowTheme.spacingMD) {
                ProgressView()
                    .tint(.primary)
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Initialization

    private func initializeViewModels() {
        let chat = ChatViewModel(
            apiClient: apiClient,
            wsManager: wsManager
        )
        chat.setModelContext(modelContext)
        chatVM = chat
        memoryVM = MemoryViewModel(apiClient: apiClient)
        jobsVM = JobsViewModel(apiClient: apiClient)
        soulVM = SoulViewModel(apiClient: apiClient)
        settingsVM = SettingsViewModel(
            authManager: authManager,
            apiClient: apiClient,
            wsManager: wsManager
        )
    }

    // MARK: - Colors

    private var bgColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.background
            : MeowTheme.Light.background
    }

    private var primaryColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textPrimary
            : MeowTheme.Light.textPrimary
    }

    private var secondaryColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textSecondary
            : MeowTheme.Light.textSecondary
    }

    private var mutedColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textMuted
            : MeowTheme.Light.textMuted
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.surface
            : MeowTheme.Light.surface
    }
}

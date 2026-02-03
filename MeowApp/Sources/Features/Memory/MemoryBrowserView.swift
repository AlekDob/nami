import SwiftUI
import SwiftData

struct MemoryBrowserView: View {
    @Bindable var viewModel: MemoryViewModel
    var onMenuTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                resultsList
            }
            .background(bgColor)
            .navigationTitle("Memory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { menuButton }
            .onAppear {
                viewModel.setModelContext(modelContext)
                viewModel.loadRecentIfNeeded()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            searchField
            searchButton
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM + 2)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(secondaryColor)
            TextField("Search memory...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .onSubmit { viewModel.search() }
        }
        .glassInput()
    }

    private var searchButton: some View {
        GlowIconButton("magnifyingglass") {
            viewModel.search()
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        Group {
            if viewModel.isSearching {
                loadingState
            } else if viewModel.results.isEmpty && !viewModel.searchQuery.isEmpty {
                emptyState
            } else if viewModel.results.isEmpty {
                idleState
            } else {
                resultItems
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .thinking, size: .medium)
            Text("Searching...")
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .sleeping, size: .medium)
            Text("No results found")
                .font(.headline)
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .sleeping, size: .large)
            Text("No memories yet")
                .font(.headline)
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultItems: some View {
        ScrollView {
            LazyVStack(spacing: MeowTheme.spacingSM + 2) {
                ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                    NavigationLink {
                        MemoryDetailView(
                            result: result,
                            content: viewModel.fileContent,
                            isLoading: viewModel.isLoadingContent
                        )
                        .onAppear { viewModel.loadFileContent(result: result) }
                    } label: {
                        MemoryRow(result: result)
                    }
                    .buttonStyle(.plain)
                    .staggeredAppear(index: index)
                }
            }
            .padding(MeowTheme.spacingMD)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var menuButton: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { onMenuTap?() } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(primaryColor)
            }
        }
    }

    // MARK: - Colors

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }
}

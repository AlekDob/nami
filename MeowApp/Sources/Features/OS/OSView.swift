import SwiftUI

struct OSView: View {
    @Bindable var viewModel: OSViewModel
    var onMenuTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingState
                } else if viewModel.creations.isEmpty {
                    emptyState
                } else {
                    creationsList
                }
            }
            .background(bgColor)
            .navigationTitle("OS")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { menuButton }
            .onAppear { viewModel.loadCreations() }
            .refreshable { viewModel.loadCreations() }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ProgressView()
            Text("Loading creations...")
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(secondaryColor)
            Text("No creations yet")
                .font(.headline)
                .foregroundColor(secondaryColor)
            Text("Ask Nami to create something for you")
                .font(.subheadline)
                .foregroundColor(secondaryColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var creationsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MeowTheme.spacingLG) {
                if !viewModel.apps.isEmpty {
                    sectionHeader("Apps", icon: "app.badge.checkmark")
                    ForEach(viewModel.apps) { creation in
                        CreationRow(creation: creation) {
                            openInSafari(creation)
                        }
                        .contextMenu { deleteMenu(creation) }
                    }
                }

                if !viewModel.documents.isEmpty {
                    sectionHeader("Documents", icon: "doc.text")
                    ForEach(viewModel.documents) { creation in
                        CreationRow(creation: creation) {
                            openInSafari(creation)
                        }
                        .contextMenu { deleteMenu(creation) }
                    }
                }

                if !viewModel.scripts.isEmpty {
                    sectionHeader("Scripts", icon: "terminal")
                    ForEach(viewModel.scripts) { creation in
                        CreationRow(creation: creation) {
                            openInSafari(creation)
                        }
                        .contextMenu { deleteMenu(creation) }
                    }
                }
            }
            .padding(MeowTheme.spacingMD)
        }
    }

    private func openInSafari(_ creation: Creation) {
        let previewURL = viewModel.getPreviewURL(for: creation)
        if let url = URL(string: previewURL) {
            openURL(url)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: icon)
            Text(title)
                .font(.headline)
        }
        .foregroundColor(secondaryColor)
        .padding(.top, MeowTheme.spacingSM)
    }

    private func deleteMenu(_ creation: Creation) -> some View {
        Button(role: .destructive) {
            viewModel.deleteCreation(creation)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

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

// MARK: - Creation Row

struct CreationRow: View {
    let creation: Creation
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MeowTheme.spacingMD) {
                Image(systemName: creation.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(creation.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(primaryColor)
                    Text(creation.relativeDate)
                        .font(.caption)
                        .foregroundColor(secondaryColor)
                }

                Spacer()

                Image(systemName: "safari")
                    .font(.body)
                    .foregroundColor(MeowTheme.accent)
            }
            .padding(MeowTheme.spacingMD)
            .background(surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerMD, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        switch creation.type {
        case .app: return MeowTheme.green
        case .document: return MeowTheme.purple
        case .script: return MeowTheme.yellow
        }
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }
}

import SwiftUI

struct JobsListView: View {
    @Bindable var viewModel: JobsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingState
                } else if viewModel.jobs.isEmpty {
                    emptyState
                } else {
                    jobsList
                }
            }
            .background(bgColor)
            .navigationTitle("Jobs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { addButton }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateJobSheet(viewModel: viewModel)
            }
            .onAppear { viewModel.loadJobs() }
            .refreshable { viewModel.loadJobs() }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .thinking, size: .medium)
            Text("Loading jobs...")
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .sleeping, size: .large)
            Text("No scheduled jobs")
                .font(.headline)
                .foregroundColor(secondaryColor)
            GlowButton("Create Job", icon: "plus", color: MeowTheme.green) {
                viewModel.showCreateSheet = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var jobsList: some View {
        ScrollView {
            LazyVStack(spacing: MeowTheme.spacingSM + 2) {
                if let error = viewModel.errorMessage { errorBanner(error) }
                ForEach(Array(viewModel.jobs.enumerated()), id: \.element.id) { index, job in
                    JobRow(job: job) { viewModel.toggleJob(job) }
                        .contextMenu { deleteMenu(job) }
                        .staggeredAppear(index: index)
                }
            }
            .padding(MeowTheme.spacingMD)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(MeowTheme.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(MeowTheme.red)
        }
        .padding(MeowTheme.spacingSM + 2)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func deleteMenu(_ job: Job) -> some View {
        Button(role: .destructive) {
            viewModel.deleteJob(job)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(MeowTheme.accent)
            }
        }
    }

    // MARK: - Colors

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var borderColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }
}

import SwiftUI

struct InstalledAppsView: View {
    @Bindable var viewModel: InstalledAppsViewModel
    @Binding var selectedApplicationID: InstalledApplication.ID?
    let filter: SidebarItem?

    private var visibleApps: [InstalledApplication] {
        viewModel.visibleApps(for: filter)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                EmptyStateView(
                    title: "Scanning Applications",
                    message: "Rhodon is preparing the installed app inventory.",
                    systemImage: "sparkle.magnifyingglass"
                )
            case let .failed(message):
                EmptyStateView(
                    title: "Scan Failed",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )
            case .loaded:
                content
            }
        }
        .navigationTitle(filter?.title ?? SidebarItem.installedApps.title)
        .searchable(
            text: $viewModel.searchText,
            placement: .toolbar,
            prompt: "Search apps"
        )
        .onChange(of: visibleApps.map(\.id)) {
            synchronizeSelection()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            SectionHeader(
                filter?.title ?? SidebarItem.installedApps.title,
                subtitle: listSubtitle
            )
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.lg)

            InstalledAppsFilterBar(viewModel: viewModel)
                .padding(.horizontal, DSSpacing.lg)

            if visibleApps.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No Apps Found",
                    message: "No applications match the current filters.",
                    systemImage: "app.dashed"
                )
                Spacer()
            } else {
                List(selection: $selectedApplicationID) {
                    ForEach(visibleApps) { application in
                        InstalledAppRowView(application: application)
                            .tag(application.id)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var listSubtitle: String {
        guard viewModel.hasActiveListFilters || filter == .migrationCandidates else {
            return "\(visibleApps.count) apps ready for review"
        }

        return "\(visibleApps.count) of \(viewModel.apps.count) apps shown"
    }

    private func synchronizeSelection() {
        guard !visibleApps.isEmpty else {
            selectedApplicationID = nil
            return
        }

        if !visibleApps.contains(where: { $0.id == selectedApplicationID }) {
            selectedApplicationID = visibleApps.first?.id
        }
    }
}

private struct InstalledAppsFilterBar: View {
    @Bindable var viewModel: InstalledAppsViewModel

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Picker("Source", selection: $viewModel.sourceFilter) {
                ForEach(InstalledAppsSourceFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)

            Picker("Status", selection: $viewModel.statusFilter) {
                ForEach(InstalledAppsStatusFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)

            if viewModel.hasActiveListFilters {
                Button {
                    viewModel.resetListFilters()
                } label: {
                    Label("Reset", systemImage: "xmark.circle")
                        .font(DSTypography.bodyEmphasized)
                }
                .buttonStyle(.borderless)
            }

            Spacer(minLength: DSSpacing.sm)
        }
    }
}

#Preview {
    @Previewable @State var selection: InstalledApplication.ID?
    let viewModel = InstalledAppsViewModel(catalogService: AppContainer.preview.catalogService)

    InstalledAppsView(
        viewModel: viewModel,
        selectedApplicationID: $selection,
        filter: .installedApps
    )
    .task {
        await viewModel.load()
    }
}

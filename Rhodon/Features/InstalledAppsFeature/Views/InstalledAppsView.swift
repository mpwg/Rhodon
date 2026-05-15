import SwiftUI

struct InstalledAppsView: View {
    let viewModel: InstalledAppsViewModel
    @Binding var selectedApplicationID: InstalledApplication.ID?
    let filter: SidebarItem?

    private var visibleApps: [InstalledApplication] {
        switch filter {
        case .migrationCandidates:
            viewModel.apps.filter(\.canMigrate)
        case .installedApps, .none:
            viewModel.apps
        }
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
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            SectionHeader(
                filter?.title ?? SidebarItem.installedApps.title,
                subtitle: "\(visibleApps.count) apps ready for review"
            )
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.lg)

            if visibleApps.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No Apps Found",
                    message: "No applications match the current source view.",
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

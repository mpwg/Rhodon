import SwiftUI

struct RootView: View {
    private let container: AppContainer

    @State private var router: AppRouter
    @State private var installedAppsViewModel: InstalledAppsViewModel

    init(container: AppContainer, router: AppRouter = AppRouter()) {
        self.container = container
        _router = State(initialValue: router)
        _installedAppsViewModel = State(
            initialValue: InstalledAppsViewModel(catalogService: container.catalogService)
        )
    }

    var body: some View {
        @Bindable var router = router

        NavigationSplitView {
            SidebarView(selection: $router.selectedSidebarItem)
                .navigationSplitViewColumnWidth(
                    min: AppWindowConfiguration.sidebarMinWidth,
                    ideal: AppWindowConfiguration.sidebarIdealWidth
                )
        } content: {
            InstalledAppsView(
                viewModel: installedAppsViewModel,
                selectedApplicationID: $router.selectedApplicationID,
                filter: router.selectedSidebarItem
            )
        } detail: {
            AppDetailView(
                viewModel: AppDetailViewModel(
                    application: installedAppsViewModel.application(
                        id: router.selectedApplicationID
                    )
                )
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PrimaryButton(title: "Scan", systemImage: "arrow.clockwise") {
                    Task {
                        await installedAppsViewModel.load()
                    }
                }
            }
        }
        .task {
            await installedAppsViewModel.load()
        }
    }
}

#Preview {
    RootView(container: .preview)
        .frame(
            width: AppWindowConfiguration.defaultWidth,
            height: AppWindowConfiguration.defaultHeight
        )
}

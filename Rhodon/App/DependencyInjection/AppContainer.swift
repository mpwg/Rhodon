import Foundation

struct AppContainer: Sendable {
    let catalogService: AppCatalogService
    let appScanner: any AppScanner
    let packageManagers: [any PackageManagerService]
    let updateService: any UpdateService

    static let preview = AppContainer(
        catalogService: AppCatalogService(repository: MockInstalledAppsRepository()),
        appScanner: FileSystemScanner(),
        packageManagers: [
            BrewService(),
            AppStoreService()
        ],
        updateService: MockUpdateService()
    )

    static let live = AppContainer(
        catalogService: AppCatalogService(repository: FileSystemInstalledAppsRepository()),
        appScanner: FileSystemScanner(),
        packageManagers: [
            BrewService(),
            AppStoreService()
        ],
        updateService: MockUpdateService()
    )
}

import Foundation

struct AppStoreService: PackageManagerService {
    let source: InstallSource = .appStore

    func isAvailable(_ application: InstalledApplication) async throws -> Bool {
        application.availableSources.contains(.appStore)
    }
}

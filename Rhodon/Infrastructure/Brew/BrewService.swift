import Foundation

struct BrewService: PackageManagerService {
    let source: InstallSource = .brew

    func isAvailable(_ application: InstalledApplication) async throws -> Bool {
        application.availableSources.contains(.brew)
    }
}

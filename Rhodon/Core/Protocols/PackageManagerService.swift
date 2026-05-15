import Foundation

protocol PackageManagerService: Sendable {
    var source: InstallSource { get }

    func isAvailable(_ application: InstalledApplication) async throws -> Bool
}

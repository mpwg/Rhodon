import Foundation

protocol SourceResolver: Sendable {
    func resolveInstalledSource(for application: InstalledApplication) async throws -> InstallSource
    func resolveAvailableSources(for application: InstalledApplication) async throws -> [InstallSource]
}

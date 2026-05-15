import Foundation

struct InstalledApplication: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let version: String
    let installedSource: InstallSource
    let availableSources: [InstallSource]
    let canMigrate: Bool
    let installPath: String

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        version: String,
        installedSource: InstallSource,
        availableSources: [InstallSource],
        canMigrate: Bool,
        installPath: String
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.installedSource = installedSource
        self.availableSources = availableSources
        self.canMigrate = canMigrate
        self.installPath = installPath
    }
}

import Foundation

struct InstalledApplication: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let version: String
    let installedSource: InstallSource
    let availableSources: [InstallSource]
    let canMigrate: Bool
    let installPath: String
    let isIOSApp: Bool
    let homebrewCaskInfo: HomebrewCaskInfo?

    init(
        id: String? = nil,
        name: String,
        bundleIdentifier: String,
        version: String,
        installedSource: InstallSource,
        availableSources: [InstallSource],
        canMigrate: Bool,
        installPath: String,
        isIOSApp: Bool = false,
        homebrewCaskInfo: HomebrewCaskInfo? = nil
    ) {
        self.id = id ?? "\(bundleIdentifier)|\(installPath)"
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.installedSource = installedSource
        self.availableSources = availableSources
        self.canMigrate = canMigrate
        self.installPath = installPath
        self.isIOSApp = isIOSApp
        self.homebrewCaskInfo = homebrewCaskInfo
    }
}

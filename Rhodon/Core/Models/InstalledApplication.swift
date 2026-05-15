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
    let appStoreMetadata: AppStoreMetadata?

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
        homebrewCaskInfo: HomebrewCaskInfo? = nil,
        appStoreMetadata: AppStoreMetadata? = nil
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
        self.appStoreMetadata = appStoreMetadata
    }
}

struct AppStoreMetadata: Codable, Hashable, Sendable {
    let receiptPath: String?
    let metadataPath: String?
    let items: [AppStoreMetadataItem]

    var isEmpty: Bool {
        receiptPath == nil && metadataPath == nil && items.isEmpty
    }
}

struct AppStoreMetadataItem: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let value: String

    var id: String {
        key
    }
}

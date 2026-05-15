import Foundation

struct MockInstalledAppsRepository: InstalledAppsRepository {
    func fetchInstalledApps() async throws -> [InstalledApplication] {
        [
            InstalledApplication(
                name: "Raycast",
                bundleIdentifier: "com.raycast.macos",
                version: "1.94.0",
                installedSource: .dmg,
                availableSources: [.brew, .dmg],
                canMigrate: true,
                installPath: "/Applications/Raycast.app"
            ),
            InstalledApplication(
                name: "Xcodes",
                bundleIdentifier: "com.robotsandpencils.XcodesApp",
                version: "2.5.0",
                installedSource: .brew,
                availableSources: [.brew],
                canMigrate: false,
                installPath: "/Applications/Xcodes.app"
            ),
            InstalledApplication(
                name: "Linear",
                bundleIdentifier: "com.linear",
                version: "1.21.3",
                installedSource: .appStore,
                availableSources: [.appStore, .dmg],
                canMigrate: true,
                installPath: "/Applications/Linear.app"
            ),
            InstalledApplication(
                name: "CleanShot X",
                bundleIdentifier: "pl.maketheweb.cleanshotx",
                version: "4.7.4",
                installedSource: .setapp,
                availableSources: [.setapp, .dmg],
                canMigrate: true,
                installPath: "/Applications/Setapp/CleanShot X.app"
            )
        ]
    }
}

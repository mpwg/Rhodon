import Foundation

protocol InstalledAppsRepository: Sendable {
    func fetchInstalledApps() async throws -> [InstalledApplication]
}

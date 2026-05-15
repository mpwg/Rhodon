import Foundation

struct AppCatalogService: Sendable {
    private let repository: any InstalledAppsRepository

    init(repository: any InstalledAppsRepository) {
        self.repository = repository
    }

    func installedApps() async throws -> [InstalledApplication] {
        try await repository.fetchInstalledApps()
    }
}

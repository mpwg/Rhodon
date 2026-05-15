import Foundation

struct FileSystemScanner: AppScanner {
    private let repository: any InstalledAppsRepository

    init(repository: any InstalledAppsRepository = MockInstalledAppsRepository()) {
        self.repository = repository
    }

    func scanInstalledApplications() async throws -> [InstalledApplication] {
        try await repository.fetchInstalledApps()
    }
}

import Foundation

struct FileSystemInstalledAppsRepository: InstalledAppsRepository {
    private let scanner: any AppScanner

    init(scanner: any AppScanner = FileSystemScanner()) {
        self.scanner = scanner
    }

    func fetchInstalledApps() async throws -> [InstalledApplication] {
        try await scanner.scanInstalledApplications()
    }
}

import Foundation

protocol AppScanner: Sendable {
    func scanInstalledApplications() async throws -> [InstalledApplication]
}

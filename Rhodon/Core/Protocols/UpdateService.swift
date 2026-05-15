import Foundation

protocol UpdateService: Sendable {
    func hasAvailableUpdate(for application: InstalledApplication) async throws -> Bool
}

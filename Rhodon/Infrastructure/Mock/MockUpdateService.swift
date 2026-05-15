import Foundation

struct MockUpdateService: UpdateService {
    func hasAvailableUpdate(for application: InstalledApplication) async throws -> Bool {
        false
    }
}

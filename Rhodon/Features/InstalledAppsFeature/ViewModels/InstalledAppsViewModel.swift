import Foundation
import Observation

@MainActor
@Observable
final class InstalledAppsViewModel {
    private let catalogService: AppCatalogService

    private(set) var state: AsyncState<[InstalledApplication]> = .idle

    init(catalogService: AppCatalogService) {
        self.catalogService = catalogService
    }

    var apps: [InstalledApplication] {
        guard case let .loaded(apps) = state else {
            return []
        }

        return apps
    }

    func load() async {
        state = .loading

        do {
            let apps = try await catalogService.installedApps()
            state = .loaded(apps)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func application(id: InstalledApplication.ID?) -> InstalledApplication? {
        guard let id else {
            return apps.first
        }

        return apps.first { $0.id == id }
    }
}

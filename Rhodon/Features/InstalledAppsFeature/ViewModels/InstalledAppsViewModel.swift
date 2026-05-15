import Foundation
import Observation

@MainActor
@Observable
final class InstalledAppsViewModel {
    private let catalogService: AppCatalogService

    private(set) var state: AsyncState<[InstalledApplication]> = .idle
    var searchText = ""
    var sourceFilter: InstalledAppsSourceFilter = .all
    var statusFilter: InstalledAppsStatusFilter = .all

    init(catalogService: AppCatalogService) {
        self.catalogService = catalogService
    }

    var apps: [InstalledApplication] {
        guard case let .loaded(apps) = state else {
            return []
        }

        return apps
    }

    var hasActiveListFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sourceFilter != .all
            || statusFilter != .all
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

    func visibleApps(for sidebarFilter: SidebarItem?) -> [InstalledApplication] {
        apps.filter { application in
            matchesSidebarFilter(application, sidebarFilter: sidebarFilter)
                && matchesSourceFilter(application)
                && matchesStatusFilter(application)
                && matchesSearch(application)
        }
    }

    func resetListFilters() {
        searchText = ""
        sourceFilter = .all
        statusFilter = .all
    }

    private func matchesSidebarFilter(
        _ application: InstalledApplication,
        sidebarFilter: SidebarItem?
    ) -> Bool {
        switch sidebarFilter {
        case .migrationCandidates:
            application.canMigrate
        case .installedApps, .none:
            true
        }
    }

    private func matchesSourceFilter(_ application: InstalledApplication) -> Bool {
        guard let source = sourceFilter.source else {
            return true
        }

        return application.installedSource == source
    }

    private func matchesStatusFilter(_ application: InstalledApplication) -> Bool {
        switch statusFilter {
        case .all:
            true
        case .migratable:
            application.canMigrate
        case .iosApp:
            application.isIOSApp
        }
    }

    private func matchesSearch(_ application: InstalledApplication) -> Bool {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else {
            return true
        }

        let searchableValues = [
            application.name,
            application.bundleIdentifier,
            application.version,
            application.installedSource.displayName,
            application.homebrewCaskInfo?.token,
            application.homebrewCaskInfo?.displayName
        ].compactMap(\.self)

        return terms.allSatisfy { term in
            searchableValues.contains { value in
                value.localizedCaseInsensitiveContains(term)
            }
        }
    }
}

enum InstalledAppsSourceFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case brew
    case appStore
    case dmg
    case setapp
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All Sources"
        case .brew:
            InstallSource.brew.displayName
        case .appStore:
            InstallSource.appStore.displayName
        case .dmg:
            InstallSource.dmg.displayName
        case .setapp:
            InstallSource.setapp.displayName
        case .unknown:
            InstallSource.unknown.displayName
        }
    }

    var source: InstallSource? {
        switch self {
        case .all:
            nil
        case .brew:
            .brew
        case .appStore:
            .appStore
        case .dmg:
            .dmg
        case .setapp:
            .setapp
        case .unknown:
            .unknown
        }
    }
}

enum InstalledAppsStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case migratable
    case iosApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All Apps"
        case .migratable:
            "Migratable"
        case .iosApp:
            "iOS Apps"
        }
    }
}

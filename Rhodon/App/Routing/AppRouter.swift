import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var selectedSidebarItem: SidebarItem? = .installedApps
    var selectedApplicationID: InstalledApplication.ID?
}

enum SidebarItem: String, CaseIterable, Identifiable, Hashable, Sendable {
    case installedApps
    case migrationCandidates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installedApps:
            "Installed Apps"
        case .migrationCandidates:
            "Migration Candidates"
        }
    }

    var systemImage: String {
        switch self {
        case .installedApps:
            "square.grid.2x2"
        case .migrationCandidates:
            "arrow.trianglehead.branch"
        }
    }
}

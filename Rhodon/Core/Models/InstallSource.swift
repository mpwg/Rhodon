import Foundation

enum InstallSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case brew
    case appStore
    case dmg
    case setapp
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brew:
            "Homebrew"
        case .appStore:
            "App Store"
        case .dmg:
            "DMG"
        case .setapp:
            "Setapp"
        case .unknown:
            "Unknown"
        }
    }
}

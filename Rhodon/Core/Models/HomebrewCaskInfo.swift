import Foundation

struct HomebrewCaskInfo: Codable, Hashable, Sendable {
    let token: String
    let tap: String?
    let names: [String]
    let description: String?
    let homepage: String?
    let url: String?
    let version: String?
    let installedVersion: String?
    let appNames: [String]

    var displayName: String {
        names.first ?? token
    }

    var homebrewPageURL: URL? {
        URL(string: "https://formulae.brew.sh/cask/\(token)")
    }
}

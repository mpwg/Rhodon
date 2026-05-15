import Foundation

struct FileSystemScanner: AppScanner {
    private let applicationDirectories: [URL]

    init(applicationDirectories: [URL] = Self.defaultApplicationDirectories) {
        self.applicationDirectories = applicationDirectories
    }

    func scanInstalledApplications() async throws -> [InstalledApplication] {
        try applicationDirectories
            .flatMap(applications(in:))
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
}

private extension FileSystemScanner {
    static var defaultApplicationDirectories: [URL] {
        [
            URL(filePath: "/Applications", directoryHint: .isDirectory),
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Applications", directoryHint: .isDirectory)
        ]
    }

    func applications(in directory: URL) throws -> [InstalledApplication] {
        guard FileManager.default.fileExists(atPath: directory.fileSystemPath) else {
            return []
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var applications: [InstalledApplication] = []

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else {
                continue
            }

            if let application = makeApplication(from: url) {
                applications.append(application)
            }

            enumerator.skipDescendants()
        }

        return applications
    }

    func makeApplication(from appURL: URL) -> InstalledApplication? {
        let info = readInfoPlist(for: appURL)
        let bundleIdentifier = stringValue("CFBundleIdentifier", in: info)
            ?? fallbackBundleIdentifier(for: appURL)
        let name = stringValue("CFBundleDisplayName", in: info)
            ?? stringValue("CFBundleName", in: info)
            ?? stringValue("CFBundleExecutable", in: info)
            ?? appURL.deletingPathExtension().lastPathComponent
        let version = stringValue("CFBundleShortVersionString", in: info)
            ?? stringValue("CFBundleVersion", in: info)
            ?? "Unknown"
        let source = installedSource(for: appURL)
        let availableSources = source == .unknown ? [] : [source]

        return InstalledApplication(
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            installedSource: source,
            availableSources: availableSources,
            canMigrate: false,
            installPath: appURL.fileSystemPath
        )
    }

    func readInfoPlist(for appURL: URL) -> [String: Any] {
        let infoPlistURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Info.plist", directoryHint: .notDirectory)

        guard
            let data = try? Data(contentsOf: infoPlistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }

    func stringValue(_ key: String, in dictionary: [String: Any]) -> String? {
        guard let value = dictionary[key] as? String, !value.isEmpty else {
            return nil
        }

        return value
    }

    func fallbackBundleIdentifier(for appURL: URL) -> String {
        let path = appURL.fileSystemPath
            .lowercased()
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: " ", with: "-")
        return "unknown\(path)"
    }

    func installedSource(for appURL: URL) -> InstallSource {
        if hasMacAppStoreReceipt(appURL) {
            return .appStore
        }

        let path = appURL.fileSystemPath
        let resolvedPath = appURL.resolvingSymlinksInPath().fileSystemPath
        let sourcePath = "\(path)\n\(resolvedPath)".lowercased()

        if sourcePath.contains("/setapp/") {
            return .setapp
        }

        if sourcePath.contains("/caskroom/") || sourcePath.contains("/homebrew/") {
            return .brew
        }

        return .dmg
    }

    func hasMacAppStoreReceipt(_ appURL: URL) -> Bool {
        let receiptURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "_MASReceipt", directoryHint: .isDirectory)
            .appending(path: "receipt", directoryHint: .notDirectory)

        return FileManager.default.fileExists(atPath: receiptURL.fileSystemPath)
    }
}

private extension URL {
    var fileSystemPath: String {
        path(percentEncoded: false)
    }
}

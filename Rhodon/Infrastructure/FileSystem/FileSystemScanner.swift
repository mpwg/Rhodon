import Foundation

struct FileSystemScanner: AppScanner {
    private let applicationDirectories: [URL]
    private let homebrewCaskProvider: any HomebrewCaskProviding

    init(
        applicationDirectories: [URL] = Self.defaultApplicationDirectories,
        homebrewCaskProvider: any HomebrewCaskProviding = ShellHomebrewCaskProvider()
    ) {
        self.applicationDirectories = applicationDirectories
        self.homebrewCaskProvider = homebrewCaskProvider
    }

    func scanInstalledApplications() async throws -> [InstalledApplication] {
        let homebrewCasks = homebrewCaskApplications()

        return try applicationDirectories
            .flatMap { directory in
                try applications(in: directory, homebrewCasks: homebrewCasks)
            }
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

    func applications(
        in directory: URL,
        homebrewCasks: Set<HomebrewCaskApplication>
    ) throws -> [InstalledApplication] {
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

            if let application = makeApplication(from: url, homebrewCasks: homebrewCasks) {
                applications.append(application)
            }

            enumerator.skipDescendants()
        }

        return applications
    }

    func makeApplication(
        from appURL: URL,
        homebrewCasks: Set<HomebrewCaskApplication>
    ) -> InstalledApplication? {
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
        let source = installedSource(
            for: appURL,
            bundleIdentifier: bundleIdentifier,
            name: name,
            homebrewCasks: homebrewCasks
        )
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
        guard let infoPlistURL = infoPlistURL(for: appURL) else {
            return [:]
        }

        guard
            let data = try? Data(contentsOf: infoPlistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }

    func infoPlistURL(for appURL: URL) -> URL? {
        let macOSInfoPlistURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Info.plist", directoryHint: .notDirectory)

        if FileManager.default.fileExists(atPath: macOSInfoPlistURL.fileSystemPath) {
            return macOSInfoPlistURL
        }

        return wrappedIOSApplicationURL(for: appURL)?
            .appending(path: "Info.plist", directoryHint: .notDirectory)
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

    func installedSource(
        for appURL: URL,
        bundleIdentifier: String,
        name: String,
        homebrewCasks: Set<HomebrewCaskApplication>
    ) -> InstallSource {
        if hasMacAppStoreReceipt(appURL) {
            return .appStore
        }

        let path = appURL.fileSystemPath
        let resolvedPath = appURL.resolvingSymlinksInPath().fileSystemPath
        let sourcePath = "\(path)\n\(resolvedPath)".lowercased()

        if sourcePath.contains("/setapp/") {
            return .setapp
        }

        if sourcePath.contains("/caskroom/")
            || sourcePath.contains("/homebrew/")
            || homebrewCasks.contains(
                HomebrewCaskApplication(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    appFileName: appURL.lastPathComponent
                )
            ) {
            return .brew
        }

        return .dmg
    }

    func hasMacAppStoreReceipt(_ appURL: URL) -> Bool {
        if hasIOSAppStoreMetadata(appURL) {
            return true
        }

        let receiptURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "_MASReceipt", directoryHint: .isDirectory)
            .appending(path: "receipt", directoryHint: .notDirectory)

        return FileManager.default.fileExists(atPath: receiptURL.fileSystemPath)
    }

    func hasIOSAppStoreMetadata(_ appURL: URL) -> Bool {
        let metadataURL = appURL
            .appending(path: "Wrapper", directoryHint: .isDirectory)
            .appending(path: "iTunesMetadata.plist", directoryHint: .notDirectory)

        guard FileManager.default.fileExists(atPath: metadataURL.fileSystemPath) else {
            return false
        }

        let metadata = readPropertyList(at: metadataURL)
        return stringValue("softwareVersionBundleId", in: metadata) != nil
            || metadata["itemId"] != nil
    }

    func wrappedIOSApplicationURL(for appURL: URL) -> URL? {
        let wrapperURL = appURL.appending(path: "Wrapper", directoryHint: .isDirectory)
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: wrapperURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return nil
        }

        return contents.first { $0.pathExtension == "app" }
    }

    func readPropertyList(at url: URL) -> [String: Any] {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }

    func homebrewCaskApplications() -> Set<HomebrewCaskApplication> {
        homebrewCaskProvider.installedCaskDirectories().reduce(into: Set<HomebrewCaskApplication>()) { applications, directory in
            applications.formUnion(homebrewCaskApplications(in: directory))
        }
    }

    func homebrewCaskApplications(in directory: URL) -> Set<HomebrewCaskApplication> {
        guard FileManager.default.fileExists(atPath: directory.fileSystemPath) else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var applications = Set<HomebrewCaskApplication>()

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else {
                continue
            }

            let info = readInfoPlist(for: url)
            guard
                let bundleIdentifier = stringValue("CFBundleIdentifier", in: info),
                let name = stringValue("CFBundleDisplayName", in: info)
                    ?? stringValue("CFBundleName", in: info)
                    ?? stringValue("CFBundleExecutable", in: info)
            else {
                enumerator.skipDescendants()
                continue
            }

            applications.insert(
                HomebrewCaskApplication(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    appFileName: url.lastPathComponent
                )
            )
            enumerator.skipDescendants()
        }

        return applications
    }
}

protocol HomebrewCaskProviding: Sendable {
    func installedCaskDirectories() -> [URL]
}

struct ShellHomebrewCaskProvider: HomebrewCaskProviding {
    func installedCaskDirectories() -> [URL] {
        guard let caskroomPath = runBrew(arguments: ["--caskroom"]).first else {
            return []
        }

        let caskroomURL = URL(filePath: caskroomPath, directoryHint: .isDirectory)
        return runBrew(arguments: ["list", "--cask"]).map { token in
            caskroomURL.appending(path: token, directoryHint: .isDirectory)
        }
    }

    private func runBrew(arguments: [String]) -> [String] {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh", directoryHint: .notDirectory)
        process.arguments = ["-lc", shellCommand(for: arguments)]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == .zero else {
            return []
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func shellCommand(for arguments: [String]) -> String {
        (["brew"] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
    }

    private func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct StaticHomebrewCaskProvider: HomebrewCaskProviding {
    let caskDirectories: [URL]

    func installedCaskDirectories() -> [URL] {
        caskDirectories
    }
}

private extension URL {
    var fileSystemPath: String {
        path(percentEncoded: false)
    }
}

private struct HomebrewCaskApplication: Hashable, Sendable {
    let bundleIdentifier: String
    let name: String
    let appFileName: String

    init(bundleIdentifier: String, name: String, appFileName: String) {
        self.bundleIdentifier = bundleIdentifier.normalizedAppIdentifier
        self.name = name.normalizedAppIdentifier
        self.appFileName = appFileName.normalizedAppIdentifier
    }
}

private extension String {
    var normalizedAppIdentifier: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

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
        let installedCaskInfos = homebrewCaskProvider.installedCaskInfos()
        let homebrewCasks = homebrewCaskApplications(caskInfos: installedCaskInfos)

        let scannedApplications = try applicationDirectories
            .flatMap { directory in
                try applications(in: directory, homebrewCasks: homebrewCasks)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return applicationsWithHomebrewAvailability(scannedApplications)
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
        let isIOSApp = isWrappedIOSApplication(appURL)
        let homebrewCaskInfo = source == .brew
            ? homebrewCaskInfo(
                for: appURL,
                bundleIdentifier: bundleIdentifier,
                name: name,
                homebrewCasks: homebrewCasks
            )
            : nil

        return InstalledApplication(
            name: name,
            bundleIdentifier: bundleIdentifier,
            version: version,
            installedSource: source,
            availableSources: availableSources,
            canMigrate: false,
            installPath: appURL.fileSystemPath,
            isIOSApp: isIOSApp,
            homebrewCaskInfo: homebrewCaskInfo
        )
    }

    func applicationsWithHomebrewAvailability(
        _ applications: [InstalledApplication]
    ) -> [InstalledApplication] {
        let candidateTokens = Set(
            applications
                .filter { $0.installedSource != .brew }
                .flatMap(homebrewCandidateTokens)
        )
        let availableCaskInfos = homebrewCaskProvider.availableCaskInfos(
            forCandidateTokens: candidateTokens
        )

        guard !availableCaskInfos.isEmpty else {
            return applications
        }

        return applications.map { application in
            guard
                application.installedSource != .brew,
                let caskInfo = matchingHomebrewCaskInfo(
                    for: application,
                    in: availableCaskInfos
                )
            else {
                return application
            }

            return applicationWithHomebrewAvailability(application, caskInfo: caskInfo)
        }
    }

    func matchingHomebrewCaskInfo(
        for application: InstalledApplication,
        in caskInfos: [HomebrewCaskInfo]
    ) -> HomebrewCaskInfo? {
        let candidateTokens = homebrewCandidateTokens(for: application)
        return caskInfos.first { caskInfo in
            candidateTokens.contains(caskInfo.token.normalizedAppIdentifier)
                || caskInfo.appNames.contains {
                    $0.normalizedAppIdentifier == application.appFileName.normalizedAppIdentifier
                }
                || caskInfo.names.contains {
                    $0.normalizedAppIdentifier == application.name.normalizedAppIdentifier
                }
        }
    }

    func applicationWithHomebrewAvailability(
        _ application: InstalledApplication,
        caskInfo: HomebrewCaskInfo
    ) -> InstalledApplication {
        var availableSources = application.availableSources
        if !availableSources.contains(.brew) {
            availableSources.append(.brew)
        }

        return InstalledApplication(
            id: application.id,
            name: application.name,
            bundleIdentifier: application.bundleIdentifier,
            version: application.version,
            installedSource: application.installedSource,
            availableSources: availableSources,
            canMigrate: application.installedSource != .brew,
            installPath: application.installPath,
            isIOSApp: application.isIOSApp,
            homebrewCaskInfo: caskInfo
        )
    }

    func homebrewCandidateTokens(for application: InstalledApplication) -> [String] {
        [
            application.name.homebrewTokenCandidate,
            application.appFileName.deletingAppExtension.homebrewTokenCandidate,
            application.bundleIdentifier.split(separator: ".").last.map(String.init)?.homebrewTokenCandidate
        ]
        .compactMap(\.self)
        .filter { !$0.isEmpty }
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
            || homebrewCasks.contains(where: {
                $0.identifier == HomebrewCaskApplicationIdentifier(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    appFileName: appURL.lastPathComponent
                )
            }) {
            return .brew
        }

        return .dmg
    }

    func homebrewCaskInfo(
        for appURL: URL,
        bundleIdentifier: String,
        name: String,
        homebrewCasks: Set<HomebrewCaskApplication>
    ) -> HomebrewCaskInfo? {
        let identifier = HomebrewCaskApplicationIdentifier(
            bundleIdentifier: bundleIdentifier,
            name: name,
            appFileName: appURL.lastPathComponent
        )

        return homebrewCasks.first { $0.identifier == identifier }?.caskInfo
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

    func isWrappedIOSApplication(_ appURL: URL) -> Bool {
        wrappedIOSApplicationURL(for: appURL) != nil
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

    func homebrewCaskApplications(caskInfos: [HomebrewCaskInfo]) -> Set<HomebrewCaskApplication> {
        let infoByToken = Dictionary(
            uniqueKeysWithValues: caskInfos.map { ($0.token.normalizedAppIdentifier, $0) }
        )

        return homebrewCaskProvider.installedCaskDirectories().reduce(into: Set<HomebrewCaskApplication>()) { applications, directory in
            let caskInfo = infoByToken[directory.lastPathComponent.normalizedAppIdentifier]
            applications.formUnion(homebrewCaskApplications(in: directory, caskInfo: caskInfo))
        }
    }

    func homebrewCaskApplications(
        in directory: URL,
        caskInfo: HomebrewCaskInfo?
    ) -> Set<HomebrewCaskApplication> {
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
                    appFileName: url.lastPathComponent,
                    caskInfo: caskInfo
                )
            )
            enumerator.skipDescendants()
        }

        return applications
    }
}

protocol HomebrewCaskProviding: Sendable {
    func installedCaskDirectories() -> [URL]
    func installedCaskInfos() -> [HomebrewCaskInfo]
    func availableCaskInfos(forCandidateTokens candidateTokens: Set<String>) -> [HomebrewCaskInfo]
}

extension HomebrewCaskProviding {
    func installedCaskInfos() -> [HomebrewCaskInfo] {
        []
    }

    func availableCaskInfos(forCandidateTokens candidateTokens: Set<String>) -> [HomebrewCaskInfo] {
        []
    }
}

struct ShellHomebrewCaskProvider: HomebrewCaskProviding {
    func installedCaskDirectories() -> [URL] {
        guard let caskroomPath = runBrewLines(arguments: ["--caskroom"]).first else {
            return []
        }

        let caskroomURL = URL(filePath: caskroomPath, directoryHint: .isDirectory)
        return runBrewLines(arguments: ["list", "--cask"]).map { token in
            caskroomURL.appending(path: token, directoryHint: .isDirectory)
        }
    }

    func installedCaskInfos() -> [HomebrewCaskInfo] {
        let tokens = runBrewLines(arguments: ["list", "--cask"])
        guard !tokens.isEmpty else {
            return []
        }

        return caskInfos(for: Set(tokens))
    }

    func availableCaskInfos(forCandidateTokens candidateTokens: Set<String>) -> [HomebrewCaskInfo] {
        let candidates = Set(candidateTokens.map(\.normalizedAppIdentifier))
        return allAvailableCaskInfos().filter { caskInfo in
            candidates.contains(caskInfo.token.normalizedAppIdentifier)
        }
    }

    private func runBrewLines(arguments: [String]) -> [String] {
        guard
            let data = runBrewData(arguments: arguments),
            let output = String(data: data, encoding: .utf8)
        else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func runBrewData(arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh", directoryHint: .notDirectory)
        process.arguments = ["-lc", shellCommand(for: arguments)]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == .zero else {
            return nil
        }

        return data
    }

    private func shellCommand(for arguments: [String]) -> String {
        (["brew"] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
    }

    private func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func allAvailableCaskInfos() -> [HomebrewCaskInfo] {
        guard let url = URL(string: "https://formulae.brew.sh/api/cask.json") else {
            return []
        }

        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        return decodeHomebrewCaskInfos(from: data)
    }

    private func caskInfos(for tokens: Set<String>) -> [HomebrewCaskInfo] {
        guard !tokens.isEmpty else {
            return []
        }

        guard let data = runBrewData(
            arguments: ["info", "--cask", "--json=v2"] + tokens.sorted()
        ) else {
            return []
        }

        return decodeHomebrewCaskInfos(from: data)
    }

    private func decodeHomebrewCaskInfos(from data: Data) -> [HomebrewCaskInfo] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let casks: [[String: Any]]
        if let array = root as? [[String: Any]] {
            casks = array
        } else if let dictionary = root as? [String: Any],
                  let nestedCasks = dictionary["casks"] as? [[String: Any]] {
            casks = nestedCasks
        } else if let dictionary = root as? [String: Any] {
            casks = [dictionary]
        } else {
            casks = []
        }

        return casks.compactMap { cask in
            guard let token = cask["token"] as? String else {
                return nil
            }

            return HomebrewCaskInfo(
                token: token,
                tap: cask["tap"] as? String,
                names: cask["name"] as? [String] ?? [],
                description: cask["desc"] as? String,
                homepage: cask["homepage"] as? String,
                url: cask["url"] as? String,
                version: cask["version"] as? String,
                installedVersion: cask["installed"] as? String,
                appNames: appNames(from: cask["artifacts"])
            )
        }
    }

    private func appNames(from artifacts: Any?) -> [String] {
        guard let artifacts = artifacts as? [[String: Any]] else {
            return []
        }

        return artifacts.flatMap { artifact -> [String] in
            if let apps = artifact["app"] as? [String] {
                return apps
            }

            if let app = artifact["app"] as? String {
                return [app]
            }

            return []
        }
    }
}

struct StaticHomebrewCaskProvider: HomebrewCaskProviding {
    let caskDirectories: [URL]
    var caskInfos: [HomebrewCaskInfo] = []

    func installedCaskDirectories() -> [URL] {
        caskDirectories
    }

    func installedCaskInfos() -> [HomebrewCaskInfo] {
        caskInfos
    }

    func availableCaskInfos(forCandidateTokens candidateTokens: Set<String>) -> [HomebrewCaskInfo] {
        caskInfos.filter { candidateTokens.contains($0.token.normalizedAppIdentifier) }
    }
}

private extension URL {
    var fileSystemPath: String {
        path(percentEncoded: false)
    }
}

private struct HomebrewCaskApplication: Hashable, Sendable {
    let identifier: HomebrewCaskApplicationIdentifier
    let caskInfo: HomebrewCaskInfo?

    init(
        bundleIdentifier: String,
        name: String,
        appFileName: String,
        caskInfo: HomebrewCaskInfo?
    ) {
        self.identifier = HomebrewCaskApplicationIdentifier(
            bundleIdentifier: bundleIdentifier,
            name: name,
            appFileName: appFileName
        )
        self.caskInfo = caskInfo
    }
}

private struct HomebrewCaskApplicationIdentifier: Hashable, Sendable {
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

    var deletingAppExtension: String {
        hasSuffix(".app") ? String(dropLast(4)) : self
    }

    var homebrewTokenCandidate: String {
        let characters = lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }

        return String(characters)
            .split(separator: "-")
            .joined(separator: "-")
    }
}

private extension InstalledApplication {
    var appFileName: String {
        URL(filePath: installPath).lastPathComponent
    }
}

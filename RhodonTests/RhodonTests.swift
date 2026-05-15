//
//  RhodonTests.swift
//  RhodonTests
//
//  Created by Matthias Wallner-Géhri on 15.05.26.
//

import Testing
import Foundation
@testable import Rhodon

struct RhodonTests {

    @MainActor
    @Test func installedAppsViewModelFiltersBySearchSourceAndStatus() async throws {
        let viewModel = InstalledAppsViewModel(
            catalogService: AppCatalogService(
                repository: StaticInstalledAppsRepository(
                    applications: [
                        makeInstalledApplication(
                            name: "Raycast",
                            bundleIdentifier: "com.raycast.macos",
                            installedSource: .dmg,
                            canMigrate: true
                        ),
                        makeInstalledApplication(
                            name: "Xcodes",
                            bundleIdentifier: "com.robotsandpencils.XcodesApp",
                            installedSource: .brew
                        ),
                        makeInstalledApplication(
                            name: "Immich",
                            bundleIdentifier: "app.alextran.immich",
                            installedSource: .appStore,
                            isIOSApp: true
                        )
                    ]
                )
            )
        )

        await viewModel.load()

        #expect(viewModel.visibleApps(for: .installedApps).map(\.name) == ["Raycast", "Xcodes", "Immich"])

        viewModel.searchText = "ray"
        #expect(viewModel.visibleApps(for: .installedApps).map(\.name) == ["Raycast"])

        viewModel.searchText = ""
        viewModel.sourceFilter = .brew
        #expect(viewModel.visibleApps(for: .installedApps).map(\.name) == ["Xcodes"])

        viewModel.sourceFilter = .all
        viewModel.statusFilter = .iosApp
        #expect(viewModel.visibleApps(for: .installedApps).map(\.name) == ["Immich"])

        viewModel.statusFilter = .migratable
        #expect(viewModel.visibleApps(for: .installedApps).map(\.name) == ["Raycast"])

        viewModel.resetListFilters()
        #expect(viewModel.visibleApps(for: .installedApps).count == 3)
    }

    @MainActor
    @Test func fileSystemScannerReadsApplicationsFromConfiguredFolders() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try makeApplicationBundle(
            at: rootURL.appending(path: "Sample.app", directoryHint: .isDirectory),
            name: "Sample",
            bundleIdentifier: "com.example.sample",
            version: "1.2.3"
        )

        let scanner = FileSystemScanner(
            applicationDirectories: [rootURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(caskDirectories: [])
        )
        let applications = try await scanner.scanInstalledApplications()

        #expect(applications.count == 1)
        #expect(applications.first?.name == "Sample")
        #expect(applications.first?.bundleIdentifier == "com.example.sample")
        #expect(applications.first?.version == "1.2.3")
        #expect(applications.first?.installedSource == .dmg)
    }

    @MainActor
    @Test func fileSystemScannerFindsNestedApplicationBundles() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let nestedDirectoryURL = rootURL.appending(path: "Utilities", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: nestedDirectoryURL,
            withIntermediateDirectories: true
        )

        try makeApplicationBundle(
            at: nestedDirectoryURL.appending(path: "Nested.app", directoryHint: .isDirectory),
            name: "Nested",
            bundleIdentifier: "com.example.nested",
            version: "4.5.6"
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [rootURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(caskDirectories: [])
        ).scanInstalledApplications()

        #expect(applications.map { $0.bundleIdentifier } == ["com.example.nested"])
    }

    @MainActor
    @Test func fileSystemScannerKeepsInstallPathsDecoded() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let appURL = rootURL.appending(
            path: "Big Mean Folder Machine 2.app",
            directoryHint: .isDirectory
        )
        try makeApplicationBundle(
            at: appURL,
            name: "Big Mean Folder Machine 2",
            bundleIdentifier: "com.example.big-mean-folder-machine",
            version: "2.43"
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [rootURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(caskDirectories: [])
        ).scanInstalledApplications()

        #expect(applications.first?.installPath.contains(appURL.lastPathComponent) == true)
        #expect(applications.first?.installPath.contains("%20") == false)
    }

    @MainActor
    @Test func fileSystemScannerDetectsMacAppStoreReceipts() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let appURL = rootURL.appending(path: "Store.app", directoryHint: .isDirectory)
        try makeApplicationBundle(
            at: appURL,
            name: "Store",
            bundleIdentifier: "com.example.store",
            version: "7.8.9"
        )

        let receiptDirectoryURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "_MASReceipt", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: receiptDirectoryURL,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: receiptDirectoryURL.appending(path: "receipt").path(),
            contents: Data("receipt".utf8)
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [rootURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(caskDirectories: [])
        ).scanInstalledApplications()

        #expect(applications.first?.installedSource == .appStore)
        #expect(applications.first?.availableSources == [.appStore])
    }

    @MainActor
    @Test func fileSystemScannerDetectsWrappedIOSAppStoreApplications() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let appURL = rootURL.appending(path: "Immich.app", directoryHint: .isDirectory)
        let wrapperURL = appURL.appending(path: "Wrapper", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: wrapperURL,
            withIntermediateDirectories: true
        )
        try makeIOSApplicationBundle(
            at: wrapperURL.appending(path: "Immich.app", directoryHint: .isDirectory),
            name: "Immich",
            bundleIdentifier: "app.alextran.immich",
            version: "2.7.5"
        )
        try makePropertyList(
            [
                "itemId": 1_613_945_652,
                "itemName": "Immich",
                "softwareVersionBundleId": "app.alextran.immich"
            ],
            at: wrapperURL.appending(path: "iTunesMetadata.plist", directoryHint: .notDirectory)
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [rootURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(caskDirectories: [])
        ).scanInstalledApplications()

        #expect(applications.first?.name == "Immich")
        #expect(applications.first?.bundleIdentifier == "app.alextran.immich")
        #expect(applications.first?.installedSource == .appStore)
        #expect(applications.first?.availableSources == [.appStore])
        #expect(applications.first?.isIOSApp == true)
    }

    @MainActor
    @Test func fileSystemScannerDetectsHomebrewCaskApplications() async throws {
        let applicationsURL = try makeTemporaryDirectory()
        let caskroomURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: applicationsURL)
            try? FileManager.default.removeItem(at: caskroomURL)
        }

        try makeApplicationBundle(
            at: applicationsURL.appending(path: "Brewlet.app", directoryHint: .isDirectory),
            name: "Brewlet",
            bundleIdentifier: "zzada.Brewlet",
            version: "1.7.4"
        )

        try makeApplicationBundle(
            at: caskroomURL
                .appending(path: "brewlet", directoryHint: .isDirectory)
                .appending(path: "1.7.4", directoryHint: .isDirectory)
                .appending(path: "Brewlet.app", directoryHint: .isDirectory),
            name: "Brewlet",
            bundleIdentifier: "zzada.Brewlet",
            version: "1.7.4"
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [applicationsURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(
                caskDirectories: [
                    caskroomURL.appending(path: "brewlet", directoryHint: .isDirectory)
                ],
                caskInfos: [
                    HomebrewCaskInfo(
                        token: "brewlet",
                        tap: "homebrew/cask",
                        names: ["Brewlet"],
                        description: "Menu bar helper for Homebrew",
                        homepage: "https://example.com/brewlet",
                        url: "https://example.com/brewlet.zip",
                        version: "1.7.4",
                        installedVersion: "1.7.4",
                        appNames: ["Brewlet.app"]
                    )
                ]
            )
        ).scanInstalledApplications()

        #expect(applications.first?.installedSource == .brew)
        #expect(applications.first?.availableSources == [.brew])
        #expect(applications.first?.homebrewCaskInfo?.token == "brewlet")
        #expect(applications.first?.homebrewCaskInfo?.description == "Menu bar helper for Homebrew")
    }

    @MainActor
    @Test func fileSystemScannerDetectsHomebrewAvailabilityForNonBrewApplications() async throws {
        let applicationsURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: applicationsURL)
        }

        try makeApplicationBundle(
            at: applicationsURL.appending(path: "Visual Studio Code.app", directoryHint: .isDirectory),
            name: "Visual Studio Code",
            bundleIdentifier: "com.microsoft.VSCode",
            version: "1.120.0"
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [applicationsURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(
                caskDirectories: [],
                caskInfos: [
                    HomebrewCaskInfo(
                        token: "visual-studio-code",
                        tap: "homebrew/cask",
                        names: ["Microsoft Visual Studio Code"],
                        description: "Open-source code editor",
                        homepage: "https://code.visualstudio.com/",
                        url: "https://update.code.visualstudio.com/latest/darwin/stable",
                        version: "1.120.0",
                        installedVersion: nil,
                        appNames: ["Visual Studio Code.app"]
                    )
                ]
            )
        ).scanInstalledApplications()

        #expect(applications.first?.installedSource == .dmg)
        #expect(applications.first?.availableSources == [.dmg, .brew])
        #expect(applications.first?.canMigrate == true)
        #expect(applications.first?.homebrewCaskInfo?.token == "visual-studio-code")
    }

    @MainActor
    @Test func fileSystemScannerIgnoresPkgOnlyCasksForHomebrewAvailability() async throws {
        let applicationsURL = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: applicationsURL)
        }

        try makeApplicationBundle(
            at: applicationsURL.appending(path: "Packages.app", directoryHint: .isDirectory),
            name: "Packages",
            bundleIdentifier: "com.brightstripe.Parcels",
            version: "2.0.10"
        )

        let applications = try await FileSystemScanner(
            applicationDirectories: [applicationsURL],
            homebrewCaskProvider: StaticHomebrewCaskProvider(
                caskDirectories: [],
                caskInfos: [
                    HomebrewCaskInfo(
                        token: "packages",
                        tap: "homebrew/cask",
                        names: ["Packages"],
                        description: "Integrated packaging environment",
                        homepage: "http://s.sudre.free.fr/Software/Packages/about.html",
                        url: "https://github.com/packagesdev/packages/releases/download/v1.2.11-GM/Packages.dmg",
                        version: "1.2.11",
                        installedVersion: nil,
                        appNames: []
                    )
                ]
            )
        ).scanInstalledApplications()

        #expect(applications.first?.installedSource == .dmg)
        #expect(applications.first?.availableSources == [.dmg])
        #expect(applications.first?.canMigrate == false)
        #expect(applications.first?.homebrewCaskInfo == nil)
    }

}

private func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )
    return directoryURL
}

@MainActor
private func makeInstalledApplication(
    name: String,
    bundleIdentifier: String,
    installedSource: InstallSource,
    canMigrate: Bool = false,
    isIOSApp: Bool = false
) -> InstalledApplication {
    InstalledApplication(
        name: name,
        bundleIdentifier: bundleIdentifier,
        version: "1.0",
        installedSource: installedSource,
        availableSources: [installedSource],
        canMigrate: canMigrate,
        installPath: "/Applications/\(name).app",
        isIOSApp: isIOSApp
    )
}

private struct StaticInstalledAppsRepository: InstalledAppsRepository {
    let applications: [InstalledApplication]

    func fetchInstalledApps() async throws -> [InstalledApplication] {
        applications
    }
}

private func makeApplicationBundle(
    at appURL: URL,
    name: String,
    bundleIdentifier: String,
    version: String
) throws {
    let contentsURL = appURL.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: contentsURL,
        withIntermediateDirectories: true
    )

    let info: [String: String] = [
        "CFBundleName": name,
        "CFBundleIdentifier": bundleIdentifier,
        "CFBundleShortVersionString": version
    ]
    let data = try PropertyListSerialization.data(
        fromPropertyList: info,
        format: .xml,
        options: .zero
    )
    try data.write(to: contentsURL.appending(path: "Info.plist"))
}

private func makeIOSApplicationBundle(
    at appURL: URL,
    name: String,
    bundleIdentifier: String,
    version: String
) throws {
    try FileManager.default.createDirectory(
        at: appURL,
        withIntermediateDirectories: true
    )

    try makePropertyList(
        [
            "CFBundleDisplayName": name,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleShortVersionString": version
        ],
        at: appURL.appending(path: "Info.plist")
    )
}

private func makePropertyList(_ propertyList: [String: Any], at url: URL) throws {
    let data = try PropertyListSerialization.data(
        fromPropertyList: propertyList,
        format: .xml,
        options: .zero
    )
    try data.write(to: url)
}

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
                ]
            )
        ).scanInstalledApplications()

        #expect(applications.first?.installedSource == .brew)
        #expect(applications.first?.availableSources == [.brew])
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

import SwiftUI

struct AppDetailView: View {
    let viewModel: AppDetailViewModel

    var body: some View {
        Group {
            if let application = viewModel.application {
                detail(for: application)
            } else {
                EmptyStateView(
                    title: "Select an App",
                    message: "Choose an installed application to inspect source and migration options.",
                    systemImage: "sidebar.right"
                )
            }
        }
        .navigationTitle(viewModel.application?.name ?? "Details")
    }

    private func detail(for application: InstalledApplication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                header(for: application)
                sourceCard(for: application)
                if let caskInfo = application.homebrewCaskInfo {
                    homebrewCard(for: caskInfo)
                }
                if let metadata = application.appStoreMetadata {
                    AppStoreMetadataCard(
                        metadata: metadata,
                        application: application
                    )
                }
                migrationCard(for: application)
            }
            .padding(DSSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(for application: InstalledApplication) -> some View {
        HStack(spacing: DSSpacing.lg) {
            AppIconView(application: application, size: DSIconSize.appDetail)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(application.name)
                        .font(DSTypography.title)
                        .foregroundStyle(DSColor.primaryText)

                    if application.isIOSApp {
                        IOSAppPill()
                    }
                }

                Text(application.installPath)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColor.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private func sourceCard(for application: InstalledApplication) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SectionHeader(
                    "Source",
                    subtitle: "Installed source and known availability"
                )

                LabeledContent("Installed From", value: application.installedSource.displayName)
                    .font(DSTypography.body)

                Divider()

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Available From")
                        .font(DSTypography.captionEmphasized)
                        .foregroundStyle(DSColor.secondaryText)

                    HStack(spacing: DSSpacing.sm) {
                        ForEach(application.availableSources) { source in
                            SourcePill(source: source)
                        }
                    }
                }
            }
        }
    }

    private func homebrewCard(for caskInfo: HomebrewCaskInfo) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SectionHeader(
                    "Homebrew Cask",
                    subtitle: caskInfo.description
                )

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    MetadataRow(title: "Token", value: caskInfo.token)
                    MetadataRow(title: "Name", value: caskInfo.displayName)
                    MetadataRow(title: "Tap", value: caskInfo.tap)
                    MetadataRow(title: "Version", value: caskInfo.version)
                    MetadataRow(title: "Installed", value: caskInfo.installedVersion)
                    MetadataRow(title: "Download", value: caskInfo.url)

                    if let url = caskInfo.homebrewPageURL {
                        LabeledContent("Homebrew Page") {
                            Link(url.absoluteString, destination: url)
                                .font(DSTypography.body)
                        }
                    }

                    if let homepage = caskInfo.homepage, let url = URL(string: homepage) {
                        LabeledContent("Homepage") {
                            Link(homepage, destination: url)
                                .font(DSTypography.body)
                        }
                    }

                    if !caskInfo.appNames.isEmpty {
                        LabeledContent("Artifacts") {
                            Text(caskInfo.appNames.joined(separator: ", "))
                                .font(DSTypography.body)
                                .foregroundStyle(DSColor.primaryText)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .font(DSTypography.body)
            }
        }
    }

    private func migrationCard(for application: InstalledApplication) -> some View {
        CardView {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: application.canMigrate ? "arrow.trianglehead.branch" : "checkmark.seal")
                    .font(DSTypography.title)
                    .foregroundStyle(application.canMigrate ? DSColor.warning : DSColor.positive)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(application.canMigrate ? "Migration Available" : "No Migration Needed")
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(DSColor.primaryText)

                    Text(application.canMigrate ? "Rhodon found another installation source for this app." : "The current source already matches the available target.")
                        .font(DSTypography.body)
                        .foregroundStyle(DSColor.secondaryText)
                }
            }
        }
    }
}

private struct AppStoreMetadataCard: View {
    let metadata: AppStoreMetadata
    let application: InstalledApplication

    private var summaryItems: [AppStoreMetadataDisplayItem] {
        AppStoreMetadataDisplayItem.summaryItems(from: metadata)
    }

    private var additionalItems: [AppStoreMetadataItem] {
        let presentedKeys = Set(summaryItems.map(\.sourceKey) + ["itemName"])
        return metadata.items.filter { !presentedKeys.contains($0.key) }
    }

    private var appStoreURL: URL? {
        guard let itemID = metadata.value(for: "itemId") else {
            return nil
        }

        return URL(string: "https://apps.apple.com/app/id\(itemID)")
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                SectionHeader(
                    application.isIOSApp ? "App Store Metadata" : "Mac App Store Metadata",
                    subtitle: application.isIOSApp ? "Store identity from the wrapped app bundle" : "Receipt and available store identity"
                )

                AppStorePageHero(
                    metadata: metadata,
                    application: application,
                    appStoreURL: appStoreURL
                )

                StoreMetadataFactStrip(items: summaryItems)

                if metadata.receiptPath != nil || metadata.metadataPath != nil {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Local Evidence")
                            .font(DSTypography.captionEmphasized)
                            .foregroundStyle(DSColor.secondaryText)

                        MetadataRow(title: "Receipt", value: metadata.receiptPath)
                        MetadataRow(title: "Metadata File", value: metadata.metadataPath)
                    }
                }

                if !additionalItems.isEmpty {
                    DisclosureGroup("Additional Metadata") {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            ForEach(additionalItems) { item in
                                MetadataRow(
                                    title: item.key.metadataDisplayTitle,
                                    value: item.value
                                )
                            }
                        }
                        .padding(.top, DSSpacing.sm)
                    }
                    .font(DSTypography.bodyEmphasized)
                }
            }
        }
    }
}

private struct AppStorePageHero: View {
    let metadata: AppStoreMetadata
    let application: InstalledApplication
    let appStoreURL: URL?

    private var storeName: String {
        metadata.value(for: "itemName") ?? application.name
    }

    private var developer: String? {
        metadata.value(for: "artistName")
    }

    private var category: String? {
        metadata.value(for: "genre")
    }

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.lg) {
            AppIconView(application: application, size: DSIconSize.appDetail)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(storeName)
                    .font(DSTypography.title)
                    .foregroundStyle(DSColor.primaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)

                if let developer {
                    Text(developer)
                        .font(DSTypography.bodyEmphasized)
                        .foregroundStyle(DSColor.appTint)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                HStack(spacing: DSSpacing.sm) {
                    if let category {
                        AppStoreCategoryPill(title: category)
                    }

                    if application.isIOSApp {
                        IOSAppPill()
                    }
                }
            }

            Spacer(minLength: DSSpacing.md)

            if let appStoreURL {
                Link(destination: appStoreURL) {
                    Label("View", systemImage: "arrow.up.right.square")
                        .font(DSTypography.bodyEmphasized)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColor.appTint)
            }
        }
        .padding(DSSpacing.lg)
        .background(DSColor.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DSCornerRadius.md,
                style: .continuous
            )
        )
    }
}

private struct StoreMetadataFactStrip: View {
    let items: [AppStoreMetadataDisplayItem]

    private let columns = [
        GridItem(.adaptive(minimum: DSSpacing.xxl * 4), spacing: DSSpacing.md)
    ]

    var body: some View {
        if !items.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.md) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: item.systemImage)
                                .foregroundStyle(DSColor.secondaryText)

                            Text(item.title.uppercased())
                                .font(DSTypography.captionEmphasized)
                                .foregroundStyle(DSColor.secondaryText)
                        }

                        Text(item.value)
                            .font(DSTypography.bodyEmphasized)
                            .foregroundStyle(DSColor.primaryText)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, DSSpacing.sm)
        }
    }
}

private struct AppStoreMetadataDisplayItem: Identifiable {
    let sourceKey: String
    let title: String
    let value: String
    let systemImage: String

    var id: String {
        sourceKey
    }

    static func summaryItems(from metadata: AppStoreMetadata) -> [AppStoreMetadataDisplayItem] {
        [
            item("artistName", title: "Developer", systemImage: "person.crop.square", metadata: metadata),
            item("genre", title: "Category", systemImage: "square.grid.2x2", metadata: metadata),
            item("kind", title: "Kind", systemImage: "shippingbox", metadata: metadata),
            item("softwareVersionBundleId", title: "Bundle ID", systemImage: "curlybraces", metadata: metadata),
            item("itemId", title: "Store ID", systemImage: "number", metadata: metadata)
        ]
        .compactMap(\.self)
    }

    private static func item(
        _ key: String,
        title: String,
        systemImage: String,
        metadata: AppStoreMetadata
    ) -> AppStoreMetadataDisplayItem? {
        guard let value = metadata.items.first(where: { $0.key == key })?.value,
              !value.isEmpty
        else {
            return nil
        }

        return AppStoreMetadataDisplayItem(
            sourceKey: key,
            title: title,
            value: value,
            systemImage: systemImage
        )
    }
}

private struct AppStoreCategoryPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DSTypography.captionEmphasized)
            .foregroundStyle(DSColor.primaryText)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.sm, style: .continuous))
    }
}

private struct MetadataRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(title) {
                Text(value)
                    .font(DSTypography.body)
                    .foregroundStyle(DSColor.primaryText)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
        }
    }
}

private extension String {
    var metadataDisplayTitle: String {
        let spaced = reduce(into: "") { result, character in
            if character.isUppercase && !result.isEmpty {
                result.append(" ")
            }

            result.append(character)
        }

        return spaced
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private extension AppStoreMetadata {
    func value(for key: String) -> String? {
        items.first { $0.key == key }?.value
    }
}

private struct SourcePill: View {
    let source: InstallSource

    var body: some View {
        Text(source.displayName)
            .font(DSTypography.captionEmphasized)
            .foregroundStyle(DSColor.primaryText)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.sm, style: .continuous))
    }
}

private struct IOSAppPill: View {
    var body: some View {
        Text("iOS app")
            .font(DSTypography.captionEmphasized)
            .foregroundStyle(DSColor.appTint)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.appTint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.sm, style: .continuous))
    }
}

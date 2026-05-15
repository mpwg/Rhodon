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
                    appStoreMetadataCard(for: metadata, application: application)
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

    private func appStoreMetadataCard(
        for metadata: AppStoreMetadata,
        application: InstalledApplication
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SectionHeader(
                    application.isIOSApp ? "App Store Metadata" : "Mac App Store Metadata",
                    subtitle: application.isIOSApp ? "iTunes metadata from the wrapped app bundle" : "Receipt and available store metadata"
                )

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    MetadataRow(title: "Receipt", value: metadata.receiptPath)
                    MetadataRow(title: "Metadata", value: metadata.metadataPath)

                    ForEach(metadata.items) { item in
                        MetadataRow(title: item.key, value: item.value)
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

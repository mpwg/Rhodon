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
                migrationCard(for: application)
            }
            .padding(DSSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(for application: InstalledApplication) -> some View {
        HStack(spacing: DSSpacing.lg) {
            Image(systemName: "app.fill")
                .font(DSTypography.title)
                .foregroundStyle(DSColor.appTint)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(application.name)
                    .font(DSTypography.title)
                    .foregroundStyle(DSColor.primaryText)

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

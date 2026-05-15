import SwiftUI

struct InstalledAppRowView: View {
    let application: InstalledApplication

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "app.fill")
                .font(DSTypography.title)
                .foregroundStyle(DSColor.appTint)
                .frame(width: DSSpacing.xxl)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(application.name)
                        .font(DSTypography.bodyEmphasized)
                        .foregroundStyle(DSColor.primaryText)
                        .lineLimit(1)

                    if application.canMigrate {
                        MigrationBadge()
                    }
                }

                Text(application.bundleIdentifier)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: DSSpacing.md)

            VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                Text(application.installedSource.displayName)
                    .font(DSTypography.captionEmphasized)
                    .foregroundStyle(DSColor.primaryText)

                Text("v\(application.version)")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColor.secondaryText)
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }
}

private struct MigrationBadge: View {
    var body: some View {
        Text("Migratable")
            .font(DSTypography.captionEmphasized)
            .foregroundStyle(DSColor.positive)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(DSColor.positive.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.sm, style: .continuous))
    }
}

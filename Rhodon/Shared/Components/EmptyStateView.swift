import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(DSTypography.title)
                .foregroundStyle(DSColor.secondaryText)

            Text(title)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSColor.primaryText)

            Text(message)
                .font(DSTypography.body)
                .foregroundStyle(DSColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.xxl)
    }
}

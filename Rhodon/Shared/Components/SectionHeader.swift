import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSTypography.sectionTitle)
                .foregroundStyle(DSColor.primaryText)

            if let subtitle {
                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColor.secondaryText)
            }
        }
    }
}

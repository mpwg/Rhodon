import SwiftUI

struct CardView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DSSpacing.lg)
            .background(DSMaterial.card)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSCornerRadius.lg, style: .continuous)
                    .stroke(DSColor.separator)
            }
            .shadow(
                color: DSShadows.card.color,
                radius: DSShadows.card.radius,
                x: DSShadows.card.x,
                y: DSShadows.card.y
            )
    }
}

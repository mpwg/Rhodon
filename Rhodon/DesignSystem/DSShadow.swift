import SwiftUI

struct DSShadow: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum DSShadows {
    static let card = DSShadow(
        color: DSColor.primaryText.opacity(0.08),
        radius: DSSpacing.md,
        x: .zero,
        y: DSSpacing.xs
    )
}

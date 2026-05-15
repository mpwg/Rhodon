import SwiftUI

enum DSColor {
    static let appTint = Color.accentColor
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary.opacity(0.72)
    static let positive = Color.green
    static let warning = Color.orange
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .windowBackgroundColor)
    static let separator = Color.secondary.opacity(0.18)
}

import AppKit
import SwiftUI

struct AppIconView: View {
    let application: InstalledApplication
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.md, style: .continuous))
    }

    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: application.installPath)
    }
}

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DSTypography.bodyEmphasized)
        }
        .buttonStyle(.borderedProminent)
        .tint(DSColor.appTint)
    }
}

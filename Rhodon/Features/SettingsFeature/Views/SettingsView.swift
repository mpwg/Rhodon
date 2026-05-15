import SwiftUI

struct SettingsView: View {
    @AppStorage("scanApplicationsFolder") private var scanApplicationsFolder = true
    @AppStorage("scanUserApplicationsFolder") private var scanUserApplicationsFolder = true

    var body: some View {
        Form {
            Section {
                Toggle("Scan /Applications", isOn: $scanApplicationsFolder)
                Toggle("Scan user Applications", isOn: $scanUserApplicationsFolder)
            } header: {
                Text("Scan Locations")
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(DSColor.primaryText)
            }
        }
        .formStyle(.grouped)
        .padding(DSSpacing.lg)
        .frame(
            minWidth: AppWindowConfiguration.minWidth / 2,
            minHeight: AppWindowConfiguration.minHeight / 2
        )
    }
}

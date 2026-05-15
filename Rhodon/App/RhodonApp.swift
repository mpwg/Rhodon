import SwiftUI

@main
struct RhodonApp: App {
    private let container = AppContainer.live
    private let lifecycle = AppLifecycle()

    init() {
        lifecycle.prepare()
    }

    var body: some Scene {
        WindowGroup("Rhodon") {
            RootView(container: container)
                .frame(
                    minWidth: AppWindowConfiguration.minWidth,
                    minHeight: AppWindowConfiguration.minHeight
                )
        }
        .defaultSize(
            width: AppWindowConfiguration.defaultWidth,
            height: AppWindowConfiguration.defaultHeight
        )

        Settings {
            SettingsView()
        }
    }
}

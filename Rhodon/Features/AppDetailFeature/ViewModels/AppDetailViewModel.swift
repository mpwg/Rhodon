import Foundation
import Observation

@MainActor
@Observable
final class AppDetailViewModel {
    let application: InstalledApplication?

    init(application: InstalledApplication?) {
        self.application = application
    }
}

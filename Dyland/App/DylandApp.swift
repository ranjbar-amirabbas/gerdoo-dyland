import SwiftUI

@main
struct DylandApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The only SwiftUI scene: Dyland is a menu-bar utility, so there is no
        // main window. The notch itself lives in an AppKit panel.
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.environment.settings)
        }
    }
}

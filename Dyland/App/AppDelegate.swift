import AppKit
import SwiftUI

/// Builds the object graph and owns the long-lived controllers.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    let environment = AppEnvironment()

    private var notchController: NotchWindowController?
    private var menuBarController: MenuBarController?

    /// True when the process was launched by `xcodebuild test`.
    ///
    /// The unit tests are hosted by this app (that is what `@testable import`
    /// of an app target requires), so without this guard every test run would
    /// pop a notch panel and a status item onto the tester's screen.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else {
            Log.app.debug("Test host launch: skipping UI setup")
            return
        }

        // Belt and braces: `LSUIElement` already keeps us out of the Dock and
        // Cmd+Tab, but an explicit policy also covers `swift run`-style launches
        // where the Info.plist is not consulted.
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController(environment: environment)
        controller.dropHandler = { [weak self] urls in
            self?.environment.dragDrop.handleDrop(urls) ?? false
        }
        controller.start()
        notchController = controller

        menuBarController = MenuBarController(actions: .init(
            openSettings: { [weak self] in self?.openSettings() },
            showNotch: { [weak self] in self?.notchController?.show() },
            hideNotch: { [weak self] in self?.notchController?.hide() },
            clearFileShelf: { [weak self] in self?.clearFileShelf() },
            quit: { NSApp.terminate(nil) }
        ))

        environment.media.onTrackChanged = { [weak self] _ in
            self?.environment.stateMachine.send(.mediaChanged)
        }
        environment.clipboard.onCapture = { [weak self] _ in
            self?.environment.stateMachine.send(.peekRequested)
        }
        // Modules start themselves from their settings, so a module the user
        // disabled never starts in the first place.
        environment.modules.start()

        seedDebugShelfIfRequested()
        openDebugSectionIfRequested()

        Log.app.info("\(AppInfo.displayName, privacy: .public) \(AppInfo.version, privacy: .public) launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.modules.stop()
        notchController?.tearDown()
        notchController = nil
        menuBarController = nil
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // The SwiftUI `Settings` scene has no public programmatic opener; this
        // is the documented AppKit selector it installs. Renamed in macOS 13,
        // hence the string selector rather than a compile-time one.
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            Log.app.error("Could not open the Settings window")
        }
    }

    private func clearFileShelf() {
        environment.fileShelf.clear()
    }

    /// Development affordance: `DYLAND_DEBUG_SHELF_SEED` takes a colon-separated
    /// list of paths and pre-fills the shelf, so the shelf UI can be exercised
    /// without performing a real drag. Debug builds only.
    private func seedDebugShelfIfRequested() {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["DYLAND_DEBUG_SHELF_SEED"] else { return }
        let urls = raw.split(separator: ":").map { URL(fileURLWithPath: String($0)) }
        environment.fileShelf.add(urls)
        #endif
    }

    /// Development affordance: `DYLAND_DEBUG_SECTION` opens the notch on a
    /// given section at launch. Debug builds only.
    private func openDebugSectionIfRequested() {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["DYLAND_DEBUG_SECTION"],
              let section = NotchSection(rawValue: raw) else { return }
        environment.stateMachine.send(.selectSection(section))
        #endif
    }
}

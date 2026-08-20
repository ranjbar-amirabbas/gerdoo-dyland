import AppKit

/// Opens a standard folder in Finder.
@MainActor
struct OpenFolderAction: QuickAction {

    let id: String
    let title: String
    let icon: String
    let directory: FileManager.SearchPathDirectory
    private let workspace: NSWorkspace
    private let fileManager: FileManager

    init(
        id: String,
        title: String,
        icon: String,
        directory: FileManager.SearchPathDirectory,
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.directory = directory
        self.workspace = workspace
        self.fileManager = fileManager
    }

    static func downloads() -> OpenFolderAction {
        OpenFolderAction(id: "open-downloads", title: "Downloads", icon: "arrow.down.circle", directory: .downloadsDirectory)
    }

    static func desktop() -> OpenFolderAction {
        OpenFolderAction(id: "open-desktop", title: "Desktop", icon: "menubar.dock.rectangle", directory: .desktopDirectory)
    }

    func execute() async throws {
        guard let url = fileManager.urls(for: directory, in: .userDomainMask).first,
              fileManager.fileExists(atPath: url.path) else {
            throw QuickActionError.locationUnavailable(title)
        }
        workspace.open(url)
    }
}

/// Brings Finder to the front.
@MainActor
struct LaunchFinderAction: QuickAction {

    let id = "launch-finder"
    let title = "Finder"
    let icon = "folder"

    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func execute() async throws {
        guard let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.finder") else {
            throw QuickActionError.applicationMissing("Finder")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await workspace.openApplication(at: url, configuration: configuration)
    }
}

/// Opens the system Screenshot app.
///
/// Deliberately *not* `screencapture -i`: a capture started by Dyland is
/// attributed to Dyland, which would make macOS demand Screen Recording
/// permission. Handing the user the system tool needs no permission at all and
/// gives them the full capture UI. Documented in the README.
@MainActor
struct ScreenshotAction: QuickAction {

    let id = "screenshot"
    let title = "Screenshot"
    let icon = "camera.viewfinder"

    private let workspace: NSWorkspace
    private let appURL: URL

    init(
        workspace: NSWorkspace = .shared,
        appURL: URL = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
    ) {
        self.workspace = workspace
        self.appURL = appURL
    }

    func execute() async throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw QuickActionError.applicationMissing("Screenshot")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await workspace.openApplication(at: appURL, configuration: configuration)
    }
}

import Foundation

/// The application's object graph, built once and passed down explicitly.
///
/// Dyland has no singletons: anything that needs a manager receives it. That is
/// what lets the tests build a whole environment with mock providers.
@MainActor
struct AppEnvironment {
    let settings: SettingsManager
    let stateMachine: NotchStateMachine
    let geometryStore: NotchGeometryStore
    let iconProvider: FileIconProvider
    let fileShelf: FileShelfManager
    let dragDrop: DragDropManager
    let media: MediaManager
    let clipboard: ClipboardMonitor
    let quickActions: QuickActionManager
    let modules: ModuleCoordinator

    /// `settings` is optional rather than a defaulted parameter because default
    /// argument expressions are evaluated in a nonisolated context, and
    /// `SettingsManager` is main-actor isolated.
    /// Real providers ship for Music and Spotify. A mock is added only when
    /// `DYLAND_DEBUG_MEDIA` is set in a debug build, so the Now Playing UI can
    /// be exercised with no player installed and no permission prompt.
    private static func makeMediaProviders() -> [MediaProvider] {
        var providers: [MediaProvider] = [
            ScriptablePlayerProvider(configuration: .appleMusic),
            ScriptablePlayerProvider(configuration: .spotify)
        ]

        #if DEBUG
        if ProcessInfo.processInfo.environment["DYLAND_DEBUG_MEDIA"] != nil {
            let mock = MockMediaProvider(id: "debug-mock", displayName: "Debug Player")
            mock.emit(
                track: MockMediaProvider.sampleTrack(),
                playback: .playing,
                position: 42
            )
            providers.insert(mock, at: 0)
        }
        #endif

        return providers
    }

    init(settings: SettingsManager? = nil) {
        let settings = settings ?? SettingsManager()
        self.settings = settings
        let stateMachine = NotchStateMachine(config: settings.notchConfig)
        let iconProvider = FileIconProvider()
        let fileShelf = FileShelfManager(iconProvider: iconProvider)

        self.stateMachine = stateMachine
        self.geometryStore = NotchGeometryStore()
        self.iconProvider = iconProvider
        self.fileShelf = fileShelf
        self.dragDrop = DragDropManager(
            shelf: fileShelf,
            stateMachine: stateMachine,
            settings: settings
        )
        let media = MediaManager(providers: Self.makeMediaProviders())
        let clipboard = ClipboardMonitor()
        self.media = media
        self.clipboard = clipboard
        self.quickActions = QuickActionManager(actions: [
            ScreenshotAction(),
            ShowClipboardAction(stateMachine: stateMachine, clipboard: clipboard),
            OpenFolderAction.downloads(),
            OpenFolderAction.desktop(),
            ClearShelfAction(shelf: fileShelf),
            LaunchFinderAction()
        ])
        self.modules = ModuleCoordinator(settings: settings, media: media, clipboard: clipboard)
    }
}

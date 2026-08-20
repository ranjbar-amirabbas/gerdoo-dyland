import AppKit
import Combine

/// Errors a provider can surface. Every one of them is recoverable by falling
/// back to another provider or to "nothing is playing".
enum MediaProviderError: LocalizedError, Equatable {
    case notInstalled(String)
    case automationDenied(String)
    case scriptingFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let app):
            return "\(app) is not installed."
        case .automationDenied(let app):
            return "\(AppInfo.displayName) needs permission to control \(app). Grant it in System Settings ▸ Privacy & Security ▸ Automation."
        case .scriptingFailed(let app, let detail):
            return "\(app) did not respond: \(detail)"
        }
    }
}

/// A source of Now Playing information.
///
/// **Deliberate design note.** macOS exposes no public, system-wide Now Playing
/// API. `MediaRemote` is private and, since macOS 15.4, entitlement-gated —
/// unentitled processes get nothing back. So Dyland integrates per application
/// and hides that behind this protocol; nothing above it knows Spotify or Music
/// exist. Adding a player means adding a conformer, not touching the UI.
///
/// Snapshots are published through Combine rather than an `AsyncStream` because
/// the manager needs the *current* value on subscribe (a stream would replay
/// nothing) and several observers may exist at once.
@MainActor
protocol MediaProvider: AnyObject {

    /// Stable identifier, also used to key the active provider.
    var id: String { get }
    /// Name shown to the user in errors and diagnostics.
    var displayName: String { get }

    /// Whether the backing application exists on this machine.
    var isInstalled: Bool { get }

    /// Latest known state. Always has a value; `.idle` before anything is known.
    var snapshots: AnyPublisher<MediaSnapshot, Never> { get }
    var currentSnapshot: MediaSnapshot { get }

    /// Begin observing. Must be idempotent and must not poll.
    func start()
    /// Stop observing and release every resource. Must be idempotent.
    func stop()

    /// Pull a fresh snapshot (used on start and after wake).
    func refresh() async

    func play() async
    func pause() async
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async

    /// Artwork for a track, if the provider can supply it. Returning `nil` is a
    /// normal outcome, not a failure.
    func artwork(for track: MediaTrack) async -> NSImage?
}

extension MediaProvider {
    func artwork(for track: MediaTrack) async -> NSImage? { nil }
}

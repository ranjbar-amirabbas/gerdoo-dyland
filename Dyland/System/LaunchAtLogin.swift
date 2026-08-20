import Foundation
import ServiceManagement

/// Wrapper over `SMAppService.mainApp`.
///
/// Registration fails in predictable ways (the app is still in `~/Downloads`,
/// or the user revoked the login item in System Settings). Those are reported
/// rather than swallowed: `apply` returns the *actual* resulting state so the
/// settings toggle can snap back instead of lying.
@MainActor
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// - Returns: the resulting state, which may differ from `enabled` on
    ///   failure. `nil` means the state is unknown (an error occurred).
    @discardableResult
    static func apply(_ enabled: Bool) -> Bool? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return isEnabled
        } catch {
            Log.settings.error("Launch at login \(enabled ? "registration" : "removal", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Human-readable explanation for the settings pane when the service is in
    /// a state the user has to resolve themselves.
    static var statusDescription: String? {
        switch SMAppService.mainApp.status {
        case .requiresApproval:
            return "Approve Dyland in System Settings ▸ General ▸ Login Items."
        case .notFound:
            return "Move Dyland to your Applications folder to enable this."
        default:
            return nil
        }
    }
}

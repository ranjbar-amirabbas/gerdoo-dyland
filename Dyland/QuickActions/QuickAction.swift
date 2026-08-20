import Foundation

/// One entry in the Quick Actions grid.
///
/// Actions receive their dependencies at construction, so adding a new one is a
/// single file plus a single registration line — no switch statement to extend
/// and no access to global state.
@MainActor
protocol QuickAction {
    var id: String { get }
    var title: String { get }
    /// SF Symbol name.
    var icon: String { get }
    /// Actions that are contextually useless (an empty shelf, say) grey out
    /// rather than disappearing, so the grid does not reflow under the cursor.
    var isEnabled: Bool { get }
    func execute() async throws
}

extension QuickAction {
    var isEnabled: Bool { true }
}

enum QuickActionError: LocalizedError, Equatable {
    case applicationMissing(String)
    case locationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .applicationMissing(let name): return "\(name) could not be found."
        case .locationUnavailable(let name): return "\(name) is not available."
        }
    }
}

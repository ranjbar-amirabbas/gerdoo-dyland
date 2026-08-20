import Combine
import Foundation

/// Ordered registry of quick actions plus the running of them.
@MainActor
final class QuickActionManager: ObservableObject {

    @Published private(set) var actions: [any QuickAction] = []
    /// Last failure, shown briefly in the notch then cleared.
    @Published private(set) var lastErrorMessage: String?

    private var errorClearTask: Task<Void, Never>?

    init(actions: [any QuickAction] = []) {
        self.actions = actions
    }

    deinit {
        errorClearTask?.cancel()
    }

    func register(_ action: any QuickAction) {
        guard !actions.contains(where: { $0.id == action.id }) else {
            Log.actions.error("Duplicate quick action id '\(action.id, privacy: .public)' ignored")
            return
        }
        actions.append(action)
    }

    func action(id: String) -> (any QuickAction)? {
        actions.first { $0.id == id }
    }

    func run(_ action: any QuickAction) async {
        guard action.isEnabled else { return }
        do {
            try await action.execute()
            Log.actions.debug("Ran quick action '\(action.id, privacy: .public)'")
        } catch {
            Log.actions.error("Quick action '\(action.id, privacy: .public)' failed: \(error.localizedDescription, privacy: .public)")
            present(error: error.localizedDescription)
        }
    }

    func run(id: String) async {
        guard let action = action(id: id) else {
            Log.actions.error("No quick action registered with id '\(id, privacy: .public)'")
            return
        }
        await run(action)
    }

    private func present(error message: String) {
        lastErrorMessage = message
        errorClearTask?.cancel()
        errorClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lastErrorMessage = nil
        }
    }
}

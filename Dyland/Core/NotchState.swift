import Foundation

/// The content module shown in the expanded notch.
enum NotchSection: String, CaseIterable, Identifiable, Sendable {
    case nowPlaying
    case fileShelf
    case clipboard
    case quickActions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .fileShelf: return "File Shelf"
        case .clipboard: return "Clipboard"
        case .quickActions: return "Quick Actions"
        }
    }

    var symbolName: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .fileShelf: return "tray.full"
        case .clipboard: return "doc.on.clipboard"
        case .quickActions: return "bolt"
        }
    }
}

/// Every visual configuration the notch can be in.
///
/// This is deliberately a single enum rather than a bag of booleans: the UI
/// derives *all* of its layout from `NotchState`, so an impossible combination
/// (hovered *and* dragging, expanded *and* collapsed) cannot be represented.
enum NotchState: Equatable, Sendable {
    /// Blended into the physical notch, showing at most a passive indicator.
    case collapsed
    /// Mouse is over the notch but the expansion delay has not elapsed.
    case hovered
    /// Fully open, showing `section`.
    case expanded(NotchSection)
    /// A drag is hovering the catch zone; the drop target is shown.
    case dragTarget
    /// A transient peek (track change, clipboard capture) shown while collapsed.
    case mediaPreview

    var isExpanded: Bool {
        if case .expanded = self { return true }
        return false
    }

    /// True whenever the notch renders wider/taller than the bare pill.
    var isOpen: Bool {
        switch self {
        case .expanded, .dragTarget: return true
        case .collapsed, .hovered, .mediaPreview: return false
        }
    }

    var section: NotchSection? {
        if case .expanded(let section) = self { return section }
        return nil
    }
}

/// Inputs the state machine understands. Nothing else may mutate `NotchState`.
enum NotchEvent: Equatable, Sendable {
    case hoverBegan
    case hoverEnded
    case clicked
    case dragEntered
    case dragExited
    case dropped
    case mediaChanged
    /// A module asks for a brief, non-intrusive peek (a clipboard capture).
    /// Treated exactly like `.mediaChanged`; a separate case keeps call sites
    /// honest about *why* the notch flickered.
    case peekRequested
    /// A module asks to be shown in full (an action result that needs reading).
    case attentionRequested(NotchSection)
    case selectSection(NotchSection)
    case dismiss

    // Timer completions. Named per-purpose so a stale timer firing after an
    // unrelated transition is a no-op instead of a surprise collapse.
    case expansionTimerFired
    case collapseTimerFired
    case previewTimerFired
}

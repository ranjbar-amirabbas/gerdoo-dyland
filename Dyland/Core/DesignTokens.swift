import SwiftUI

/// How much vertical/horizontal room the expanded panel gets.
enum NotchSizing: String, CaseIterable, Identifiable, Sendable {
    case compact
    case comfortable

    var id: String { rawValue }
    var title: String { self == .compact ? "Compact" : "Comfortable" }
}

/// User-facing animation budget. `.none` still switches states — it just does
/// so instantly, which is also what we fall back to under Reduce Motion.
enum AnimationIntensity: String, CaseIterable, Identifiable, Sendable {
    case none
    case subtle
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .subtle: return "Subtle"
        case .full: return "Full"
        }
    }
}

/// Shared visual constants. Kept in one place so the notch, the shelf and the
/// settings previews cannot drift apart.
enum DesignTokens {

    // MARK: Materials

    /// The notch body is near-black rather than a vibrancy material: it has to
    /// blend with the physical notch cutout, which is opaque black.
    static let bodyColor = Color.black
    static let bodyOpacityCollapsed: Double = 1.0
    /// Sits on top of a blurred material, so this is a tint rather than the
    /// whole background — enough to keep white text legible over any desktop.
    static let bodyOpacityExpanded: Double = 0.72

    static let strokeColor = Color.white.opacity(0.08)
    static let strokeWidth: CGFloat = 0.5

    static let shadowColor = Color.black.opacity(0.35)
    static let shadowRadius: CGFloat = 18
    static let shadowYOffset: CGFloat = 8

    // MARK: Content

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)
    static let accent = Color.white.opacity(0.9)
    static let controlBackground = Color.white.opacity(0.10)
    static let controlBackgroundHover = Color.white.opacity(0.18)
    static let dropTargetStroke = Color.white.opacity(0.55)

    // MARK: Metrics

    static let contentPadding: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let itemCornerRadius: CGFloat = 10

    // MARK: Animations

    static func expansion(_ intensity: AnimationIntensity) -> Animation? {
        switch intensity {
        case .none: return nil
        case .subtle: return .spring(response: 0.30, dampingFraction: 0.90)
        case .full: return .spring(response: 0.42, dampingFraction: 0.78)
        }
    }

    static func contentTransition(_ intensity: AnimationIntensity) -> Animation? {
        switch intensity {
        case .none: return nil
        case .subtle: return .easeOut(duration: 0.14)
        case .full: return .spring(response: 0.30, dampingFraction: 0.85)
        }
    }

    static func feedback(_ intensity: AnimationIntensity) -> Animation? {
        switch intensity {
        case .none: return nil
        case .subtle: return .easeOut(duration: 0.12)
        case .full: return .spring(response: 0.22, dampingFraction: 0.7)
        }
    }
}

import CoreGraphics
import Foundation

/// Screen facts the geometry resolver needs, decoupled from `NSScreen` so the
/// resolution rules can be unit tested for hardware we do not have.
struct ScreenDescriptor: Equatable, Sendable {
    var frame: CGRect
    /// `NSScreen.safeAreaInsets.top` — the notch height on notched displays,
    /// zero on everything else.
    var safeAreaTopInset: CGFloat
    /// Width of `NSScreen.auxiliaryTopLeftArea`, zero when absent.
    var auxiliaryTopLeftWidth: CGFloat
    /// Width of `NSScreen.auxiliaryTopRightArea`, zero when absent.
    var auxiliaryTopRightWidth: CGFloat
    var isBuiltIn: Bool

    /// A display only counts as notched when it reports *both* auxiliary areas
    /// and a top inset. External displays report neither; a display with an
    /// inset but no auxiliary areas is something else (e.g. a legacy safe area)
    /// and is treated as un-notched.
    var hasPhysicalNotch: Bool {
        safeAreaTopInset > 0 && auxiliaryTopLeftWidth > 0 && auxiliaryTopRightWidth > 0
    }

    var measuredNotchWidth: CGFloat {
        max(0, frame.width - auxiliaryTopLeftWidth - auxiliaryTopRightWidth)
    }
}

/// Tunables that come from user settings rather than from the hardware.
struct NotchMetrics: Equatable, Sendable {
    var sizing: NotchSizing = .comfortable

    /// Used when the display has no camera housing to hide behind.
    var syntheticNotchSize = CGSize(width: 172, height: 26)

    var expandedWidth: CGFloat { sizing == .compact ? 460 : 540 }
    var expandedHeight: CGFloat { sizing == .compact ? 146 : 168 }
    var windowPadding: CGFloat { 28 }

    /// Minimum pill width, so a very narrow notch still has room for the
    /// collapsed indicators.
    var minimumCollapsedWidth: CGFloat { 150 }

    /// Extra width added on each side of the notch in the peek presentation.
    var peekAccessoryWidth: CGFloat { 58 }
}

/// Resolves a `NotchGeometry` from a screen.
///
/// Pure and stateless: `resolve` is a function of its inputs only, which keeps
/// multi-monitor behaviour predictable and testable.
enum NotchGeometryProvider {

    static func resolve(screen: ScreenDescriptor, metrics: NotchMetrics = NotchMetrics()) -> NotchGeometry {
        let notchSize: CGSize
        if screen.hasPhysicalNotch {
            notchSize = CGSize(
                width: max(screen.measuredNotchWidth, metrics.minimumCollapsedWidth),
                height: screen.safeAreaTopInset
            )
        } else {
            notchSize = metrics.syntheticNotchSize
        }

        let collapsedSize = CGSize(
            width: max(notchSize.width, metrics.minimumCollapsedWidth),
            height: notchSize.height
        )

        let peekSize = CGSize(
            width: collapsedSize.width + metrics.peekAccessoryWidth * 2,
            height: collapsedSize.height
        )

        // Never let the panel exceed the display; a 12" external screen or a
        // rotated monitor would otherwise render the notch off-screen.
        let maxWidth = max(collapsedSize.width, screen.frame.width - metrics.windowPadding * 2 - 40)
        let expandedSize = CGSize(
            width: min(metrics.expandedWidth, maxWidth),
            height: min(metrics.expandedHeight, max(80, screen.frame.height * 0.4))
        )

        return NotchGeometry(
            screenFrame: screen.frame,
            hasPhysicalNotch: screen.hasPhysicalNotch,
            notchSize: notchSize,
            collapsedSize: collapsedSize,
            peekSize: CGSize(width: min(peekSize.width, expandedSize.width), height: peekSize.height),
            expandedSize: expandedSize,
            // A real notch already has square top corners cut into the bezel;
            // rounding ours there would show a sliver of desktop.
            topCornerRadius: screen.hasPhysicalNotch ? 0 : 8,
            bottomCornerRadius: 22,
            windowPadding: metrics.windowPadding
        )
    }
}

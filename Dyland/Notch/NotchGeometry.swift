import CoreGraphics
import Foundation

/// Everything the notch UI needs to lay itself out on one specific screen.
///
/// Nothing here is hard-coded to a MacBook model: the values are derived from
/// the screen's reported safe area, with documented fallbacks for displays that
/// have no notch at all.
struct NotchGeometry: Equatable, Sendable {

    /// Full frame of the target screen, in AppKit global (bottom-left) coords.
    var screenFrame: CGRect
    /// True when the display reports a real camera housing.
    var hasPhysicalNotch: Bool

    /// Size of the physical cutout (or the synthetic pill on non-notch Macs).
    var notchSize: CGSize
    var collapsedSize: CGSize
    /// Slightly wider than the notch so indicators can live either side of the
    /// camera housing, which is the only place they are actually visible.
    var peekSize: CGSize
    var expandedSize: CGSize

    /// Radius where the body meets the top edge of the screen. Zero on notched
    /// displays so the pill fuses with the cutout; rounded otherwise.
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    /// Slack around the panel so shadows and the drag catch zone have room.
    var windowPadding: CGFloat

    /// Top edge of the screen in global coordinates.
    var screenTop: CGFloat { screenFrame.maxY }

    var windowSize: CGSize {
        CGSize(
            width: expandedSize.width + windowPadding * 2,
            height: expandedSize.height + windowPadding
        )
    }

    /// The panel is a fixed-size window pinned to the top centre of the screen.
    /// It never resizes; the pill animates inside it.
    var windowFrame: CGRect {
        let size = windowSize
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Drop-catch region, in the host view's flipped (top-left origin) space.
    /// Deliberately wider and taller than the collapsed pill so a drag heading
    /// for the notch registers before it is pixel-perfect.
    var dragCatchZone: CGRect {
        let width = max(collapsedSize.width + 140, expandedSize.width * 0.6)
        let height = collapsedSize.height + 40
        let size = windowSize
        return CGRect(
            x: (size.width - width) / 2,
            y: 0,
            width: width,
            height: height
        )
    }

    func size(for presentation: NotchPresentation) -> CGSize {
        switch presentation {
        case .collapsed: return collapsedSize
        case .peek: return peekSize
        case .open: return expandedSize
        }
    }

    /// Interactive (hit-testable) region, in the same flipped space. Everything
    /// outside is click-through so the huge transparent window never steals
    /// events from the app underneath.
    func interactiveRect(for presentation: NotchPresentation) -> CGRect {
        let size = windowSize
        let contentSize = self.size(for: presentation)
        return CGRect(
            x: (size.width - contentSize.width) / 2,
            y: 0,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    /// Fallback used when no usable screen information is available.
    static let fallback = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        hasPhysicalNotch: false,
        notchSize: CGSize(width: 180, height: 26),
        collapsedSize: CGSize(width: 180, height: 26),
        peekSize: CGSize(width: 300, height: 26),
        expandedSize: CGSize(width: 480, height: 168),
        topCornerRadius: 10,
        bottomCornerRadius: 20,
        windowPadding: 28
    )
}

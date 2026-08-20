import SwiftUI

/// The notch body outline: flush (or nearly flush) at the screen edge, rounded
/// where it hangs into the desktop.
///
/// `UnevenRoundedRectangle` gives per-corner radii and animates them, so the
/// collapsed→expanded morph is a single interpolation rather than a crossfade.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        return UnevenRoundedRectangle(
            topLeadingRadius: min(topRadius, limit),
            bottomLeadingRadius: min(bottomRadius, limit),
            bottomTrailingRadius: min(bottomRadius, limit),
            topTrailingRadius: min(topRadius, limit),
            style: .continuous
        )
        .path(in: rect)
    }
}

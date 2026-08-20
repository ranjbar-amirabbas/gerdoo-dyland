import Foundation

/// Decides which display the notch belongs on.
///
/// Pure, so the multi-monitor policy can be tested for hardware combinations
/// that are not plugged in: a MacBook plus an external, an external only, a
/// clamshell with no displays at all.
enum NotchScreenSelector {

    /// Default policy (Feature 9): prefer a display that actually has a camera
    /// housing to hide in, then the display that owns the menu bar (which
    /// AppKit always reports first), then nothing.
    ///
    /// - Returns: index into `screens`, or `nil` when there is no usable display.
    static func selectIndex(from screens: [ScreenDescriptor]) -> Int? {
        if let notched = screens.firstIndex(where: \.hasPhysicalNotch) {
            return notched
        }
        return screens.isEmpty ? nil : 0
    }
}

import AppKit

extension NSScreen {

    /// Bridges `NSScreen` into the hardware-independent `ScreenDescriptor` the
    /// geometry resolver consumes.
    var notchDescriptor: ScreenDescriptor {
        ScreenDescriptor(
            frame: frame,
            safeAreaTopInset: safeAreaInsets.top,
            auxiliaryTopLeftWidth: auxiliaryTopLeftArea?.width ?? 0,
            auxiliaryTopRightWidth: auxiliaryTopRightArea?.width ?? 0,
            isBuiltIn: isBuiltInDisplay
        )
    }

    /// There is no public "is this the internal panel" flag. Reporting a real
    /// notch is a sufficient positive signal; otherwise we fall back to the
    /// screen that owns the menu bar, which is the primary display.
    var isBuiltInDisplay: Bool {
        if safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil { return true }
        return self == NSScreen.screens.first
    }

    /// Stable identity across reconfigurations, used to re-find "the same"
    /// screen after a display is unplugged and replugged.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

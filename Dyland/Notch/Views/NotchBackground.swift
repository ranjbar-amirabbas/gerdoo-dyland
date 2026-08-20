import SwiftUI

/// The notch body's fill.
///
/// Collapsed it must be *opaque black*: the whole point is to be
/// indistinguishable from the camera housing. Expanded it becomes a blurred
/// dark panel so it reads as a surface floating over the desktop.
struct NotchBackground: View {

    let isOpen: Bool

    var body: some View {
        ZStack {
            if isOpen {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                DesignTokens.bodyColor.opacity(DesignTokens.bodyOpacityExpanded)
            } else {
                DesignTokens.bodyColor.opacity(DesignTokens.bodyOpacityCollapsed)
            }
        }
    }
}

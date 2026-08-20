import AppKit
import SwiftUI

/// `NSVisualEffectView` bridged into SwiftUI.
///
/// SwiftUI's `.background(.ultraThinMaterial)` only samples what is *inside*
/// the window. The notch panel is transparent, so it has to blend with what is
/// behind the window instead, which requires `.behindWindow` blending on an
/// AppKit effect view.
struct VisualEffectBackground: NSViewRepresentable {

    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // The panel is never key, so `.followsWindowActiveState` would leave the
        // material permanently inactive and flat.
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

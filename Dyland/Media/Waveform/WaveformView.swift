import SwiftUI

/// Equaliser-style bars shown while media plays.
///
/// Backed by Core Animation (`WaveformBarsView`) rather than a SwiftUI `Canvas`
/// so that an always-visible indicator costs this process nothing per frame —
/// see that type for the measurements behind the decision.
///
/// `levels` is the seam for real audio: pass sampled values from an
/// `AudioLevelProvider` and the bars follow them instead of self-animating.
struct WaveformView: NSViewRepresentable {

    var barCount: Int = 4
    var isAnimating: Bool = true
    /// Explicit levels. Overrides everything else — the hook for a future real
    /// audio tap.
    var levels: [Double]?
    /// Used to draw a pleasant frozen pattern when the bars are not animating
    /// (paused playback, Reduce Motion, or animations turned off) instead of a
    /// row of identical stubs.
    var restingLevelProvider: AudioLevelProvider = ProceduralLevelProvider()

    private var effectiveLevels: [Double]? {
        if let levels { return levels }
        guard !isAnimating else { return nil }
        return restingLevelProvider.levels(count: barCount, at: 0)
    }

    func makeNSView(context: Context) -> WaveformBarsView {
        let view = WaveformBarsView()
        view.barCount = barCount
        view.barColor = NSColor.white.withAlphaComponent(0.9)
        view.levels = effectiveLevels
        view.isAnimating = isAnimating
        return view
    }

    func updateNSView(_ nsView: WaveformBarsView, context: Context) {
        nsView.barCount = barCount
        nsView.levels = effectiveLevels
        // Assigned last: the view stops self-animating as soon as explicit
        // levels arrive, so the order matters.
        nsView.isAnimating = isAnimating
    }
}

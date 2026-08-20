import AppKit

/// Core Animation implementation of the equaliser bars.
///
/// **Why not SwiftUI `Canvas`.** The notch panel is a large transparent window.
/// Any per-frame drawing inside it makes the window server recomposite the
/// whole surface *and* wakes this process 20–120 times a second. Measured on an
/// M3 Air, a four-bar `Canvas` waveform in the collapsed pill cost ~5.4% CPU
/// and 60 MB while music played — for an always-visible indicator in a utility
/// that is otherwise at 0.0%, that is not a reasonable price.
///
/// Core Animation runs the animation in the render server instead: once the
/// animations are installed, this process does no per-frame work at all.
final class WaveformBarsView: NSView {

    var barCount: Int = 4 { didSet { if barCount != oldValue { rebuildBars() } } }
    var barColor: NSColor = .white { didSet { applyColor() } }

    var isAnimating: Bool = false {
        didSet {
            guard isAnimating != oldValue else { return }
            isAnimating ? startAnimating() : stopAnimating()
        }
    }

    /// Explicit levels (0...1). When set, the bars stop self-animating and
    /// follow these values — the hook a real audio-tap `AudioLevelProvider`
    /// will use once one exists.
    var levels: [Double]? {
        didSet { applyExplicitLevels() }
    }

    private var bars: [CALayer] = []
    private let restingScale: CGFloat = 0.28
    private let animationKey = "dyland.waveform"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        rebuildBars()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WaveformBarsView is created programmatically only")
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        layoutBars()
    }

    /// Re-installing animations is required after the view leaves and re-enters
    /// the window: AppKit detaches layer animations when a layer is removed
    /// from the render tree.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, isAnimating {
            startAnimating()
        }
    }

    private func rebuildBars() {
        bars.forEach { $0.removeFromSuperlayer() }
        bars = (0..<max(0, barCount)).map { _ in
            let bar = CALayer()
            bar.backgroundColor = barColor.cgColor
            // Anchored at the vertical centre so a scale animation grows the
            // bar symmetrically rather than from the top edge.
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer?.addSublayer(bar)
            return bar
        }
        layoutBars()
        if isAnimating { startAnimating() }
    }

    private func layoutBars() {
        guard !bars.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(bars.count - 1)
        let barWidth = max(1, (bounds.width - totalSpacing) / CGFloat(bars.count))

        // Position changes must not animate implicitly, or a resize turns into
        // a visible slide.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: bounds.height)
            bar.position = CGPoint(
                x: CGFloat(index) * (barWidth + spacing) + barWidth / 2,
                y: bounds.midY
            )
            bar.cornerRadius = barWidth / 2
            if !isAnimating && levels == nil {
                bar.transform = CATransform3DMakeScale(1, restingScale, 1)
            }
        }
        CATransaction.commit()
    }

    private func applyColor() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bars.forEach { $0.backgroundColor = barColor.cgColor }
        CATransaction.commit()
    }

    private func startAnimating() {
        guard levels == nil else { return }
        for (index, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: animationKey)

            // Incommensurable periods plus a per-bar time offset: neighbours
            // never move in lockstep and the pattern does not visibly repeat.
            let duration = 0.46 + Double(index % 4) * 0.13
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = restingScale
            animation.toValue = 1.0
            animation.duration = duration
            animation.timeOffset = Double(index) * 0.21
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.isRemovedOnCompletion = false
            bar.add(animation, forKey: animationKey)
        }
    }

    private func stopAnimating() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for bar in bars {
            bar.removeAnimation(forKey: animationKey)
            bar.transform = CATransform3DMakeScale(1, restingScale, 1)
        }
        CATransaction.commit()
    }

    private func applyExplicitLevels() {
        guard let levels else {
            if isAnimating { startAnimating() }
            return
        }
        stopAnimating()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() where index < levels.count {
            let clamped = max(0.05, min(1, CGFloat(levels[index])))
            bar.transform = CATransform3DMakeScale(1, clamped, 1)
        }
        CATransaction.commit()
    }
}

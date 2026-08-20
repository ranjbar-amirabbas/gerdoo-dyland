import Foundation

/// Supplies normalised bar heights for the waveform.
///
/// Real audio levels need a system audio tap, which costs a Screen Recording
/// style permission (see README). The MVP therefore ships a procedural
/// implementation behind this protocol; swapping in a tap later means adding a
/// conformer, not touching the view.
protocol AudioLevelProvider: Sendable {
    /// - Parameters:
    ///   - count: number of bars to fill.
    ///   - time: monotonically increasing seconds; the view passes its timeline
    ///     date so the animation is a pure function of time (no stored state,
    ///     nothing to reset, nothing to leak).
    /// - Returns: `count` values in `0...1`.
    func levels(count: Int, at time: TimeInterval) -> [Double]
}

/// Sum-of-sines bar animation.
///
/// Each bar mixes two incommensurable frequencies so the pattern never visibly
/// repeats, and a per-bar phase offset keeps neighbours from moving in lockstep.
struct ProceduralLevelProvider: AudioLevelProvider {

    var speed: Double = 1.9
    var floorLevel: Double = 0.18

    func levels(count: Int, at time: TimeInterval) -> [Double] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let phase = Double(index) * 0.9
            let fast = sin(time * speed + phase)
            let slow = sin(time * speed * 0.37 + phase * 1.7)
            // Weighted mix mapped from -1...1 into floorLevel...1.
            let mixed = (fast * 0.65 + slow * 0.35 + 1) / 2
            return floorLevel + mixed * (1 - floorLevel)
        }
    }
}

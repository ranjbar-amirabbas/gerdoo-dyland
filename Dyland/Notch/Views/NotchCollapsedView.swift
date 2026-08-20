import SwiftUI

/// What the notch shows while it is blended into the physical cutout.
///
/// The rule here is restraint: an empty black pill is the correct default. Only
/// presentations that carry information draw anything at all.
struct NotchCollapsedView: View {

    let state: NotchState
    let presentation: NotchPresentation

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var clipboard: ClipboardMonitor
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var geometryStore: NotchGeometryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if presentation == .peek {
                NotchPeekView(
                    notchWidth: geometryStore.geometry.notchSize.width,
                    content: peekContent,
                    showWaveform: settings.showWaveform,
                    animatesWaveform: !reduceMotion && settings.animationIntensity != .none
                )
                .transition(.opacity)
            } else if state == .hovered {
                affordance
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A clipboard capture only wins the pill if it is newer than the current
    /// track's snapshot; otherwise music keeps it.
    private var peekContent: NotchPeekContent {
        let clipboardDate = clipboard.lastCaptureDate
        let mediaDate = media.snapshot?.capturedAt

        if let clipboardDate, clipboardDate > (mediaDate ?? .distantPast),
           let entry = clipboard.entries.first {
            return .clipboard(summary: entry.preview, symbol: entry.symbolName)
        }
        if media.track != nil {
            return .media(artwork: media.artwork, isPlaying: media.isPlaying)
        }
        return .none
    }

    /// A hairline hint that the pill is interactive, sitting just above the
    /// bottom edge so it reads as "there is more below".
    private var affordance: some View {
        VStack {
            Spacer(minLength: 0)
            Capsule()
                .fill(DesignTokens.tertiaryText)
                .frame(width: 26, height: 2.5)
                .padding(.bottom, 4)
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}

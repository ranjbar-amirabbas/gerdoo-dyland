import SwiftUI

/// Root of the SwiftUI hierarchy inside the notch panel.
///
/// The panel window never resizes — everything you see growing and shrinking is
/// this view animating its own frame inside a fixed transparent window. That is
/// what keeps the spring smooth; per-frame `NSWindow.setFrame` is not.
struct NotchRootView: View {

    @EnvironmentObject private var stateMachine: NotchStateMachine
    @EnvironmentObject private var geometryStore: NotchGeometryStore
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var media: MediaManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: NotchState { stateMachine.state }
    private var geometry: NotchGeometry { geometryStore.geometry }

    /// Reduce Motion downgrades to instant transitions regardless of the
    /// user's animation-intensity preference.
    private var intensity: AnimationIntensity {
        reduceMotion ? .none : settings.animationIntensity
    }

    /// Size is derived from the presentation, not the state: a collapsed notch
    /// with music loaded is wider than one without.
    private var presentation: NotchPresentation {
        NotchPresentationResolver.resolve(
            state: state,
            hasMedia: media.track != nil,
            waveformEnabled: settings.showWaveform
        )
    }

    private var contentSize: CGSize { geometry.size(for: presentation) }

    var body: some View {
        VStack(spacing: 0) {
            notchBody
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DesignTokens.expansion(intensity), value: state)
        .animation(DesignTokens.expansion(intensity), value: presentation)
    }

    private var notchBody: some View {
        content
            .frame(width: contentSize.width, height: contentSize.height)
            .background(background)
            .clipShape(shape)
            .overlay(
                shape.stroke(DesignTokens.strokeColor, lineWidth: DesignTokens.strokeWidth)
            )
            .shadow(
                color: state.isOpen ? DesignTokens.shadowColor : .clear,
                radius: DesignTokens.shadowRadius,
                y: DesignTokens.shadowYOffset
            )
            .contentShape(shape)
            .onTapGesture { stateMachine.send(.clicked) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(AppInfo.displayName) notch")
            .accessibilityHint(state.isOpen ? "Click to collapse" : "Click to expand")
    }

    private var shape: NotchShape {
        NotchShape(
            topRadius: geometry.topCornerRadius,
            bottomRadius: state.isOpen ? geometry.bottomCornerRadius : geometry.bottomCornerRadius * 0.55
        )
    }

    private var background: some View {
        NotchBackground(isOpen: state.isOpen)
    }

    @ViewBuilder
    private var content: some View {
        if state.isOpen {
            NotchExpandedView(state: state, intensity: intensity)
        } else {
            NotchCollapsedView(state: state, presentation: presentation)
        }
    }
}

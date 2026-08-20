import SwiftUI

/// The open panel: a section switcher above a swappable content area.
struct NotchExpandedView: View {

    let state: NotchState
    let intensity: AnimationIntensity

    @EnvironmentObject private var stateMachine: NotchStateMachine
    @EnvironmentObject private var geometryStore: NotchGeometryStore
    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Nothing may be drawn in this strip: on a notched Mac the camera
            // housing physically covers it. The panel is wider than the notch,
            // so the areas either side stay available for future use.
            Color.clear
                .frame(height: geometryStore.geometry.notchSize.height)

            header
                .frame(height: 20)
                .padding(.horizontal, DesignTokens.contentPadding)

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DesignTokens.contentPadding)
                .padding(.top, 8)
                .padding(.bottom, DesignTokens.contentPadding)
        }
        .animation(DesignTokens.contentTransition(intensity), value: state)
    }

    @ViewBuilder
    private var header: some View {
        if state == .dragTarget {
            Text("Drop to add")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .transition(.opacity)
        } else {
            NotchSectionSwitcher(
                sections: settings.enabledSections,
                selection: state.section,
                onSelect: { stateMachine.send(.selectSection($0)) }
            )
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        if state == .dragTarget {
            NotchDropTargetView()
        } else if let section = state.section {
            NotchSectionContentView(section: section)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .id(section)
        } else {
            EmptyView()
        }
    }
}

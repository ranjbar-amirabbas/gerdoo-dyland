import SwiftUI

/// Compact segmented control for choosing the visible module.
///
/// Hidden entirely when only one module is enabled — a one-item switcher is
/// noise, not navigation.
struct NotchSectionSwitcher: View {

    let sections: [NotchSection]
    let selection: NotchSection?
    let onSelect: (NotchSection) -> Void

    var body: some View {
        if sections.count > 1 {
            HStack(spacing: 4) {
                ForEach(sections) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 26, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(section == selection
                                          ? DesignTokens.controlBackgroundHover
                                          : Color.clear)
                            )
                            .foregroundStyle(section == selection
                                             ? DesignTokens.primaryText
                                             : DesignTokens.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(section == selection ? [.isSelected] : [])
                }
            }
        }
    }
}

import SwiftUI

/// Maps a `NotchSection` to its module view.
///
/// Sections whose module has not landed yet fall through to a placeholder;
/// each phase removes one case from that fallback.
struct NotchSectionContentView: View {

    let section: NotchSection

    var body: some View {
        switch section {
        case .nowPlaying:
            NowPlayingView()
        case .fileShelf:
            FileShelfView()
        case .clipboard:
            ClipboardView()
        case .quickActions:
            QuickActionsView()
        }
    }
}

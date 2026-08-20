import Foundation

/// The app's own identity, read from its bundle.
///
/// One source of truth so a product rename is a build-setting change rather
/// than a search-and-replace through every user-facing string.
enum AppInfo {

    /// Name shown to the user — in the menu bar, in permission explanations,
    /// and in accessibility labels.
    static let displayName: String = {
        let info = Bundle.main.infoDictionary
        if let display = info?["CFBundleDisplayName"] as? String, !display.isEmpty { return display }
        if let name = info?["CFBundleName"] as? String, !name.isEmpty { return name }
        return "gerdoo-dyland"
    }()

    static let version: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
}

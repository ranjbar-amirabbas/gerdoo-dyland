import AppKit

/// The status-bar item. Dyland has no Dock icon, so this is the only place the
/// user can reach the app when the notch is hidden.
@MainActor
final class MenuBarController: NSObject {

    struct Actions {
        var openSettings: () -> Void
        var showNotch: () -> Void
        var hideNotch: () -> Void
        var clearFileShelf: () -> Void
        var quit: () -> Void
    }

    private let statusItem: NSStatusItem
    private let actions: Actions

    init(actions: Actions) {
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        statusItem.menu = buildMenu()
    }

    deinit {
        // NSStatusBar keeps its own strong reference; without this the icon
        // lingers after the controller is released.
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Dyland"
        )
        button.image?.isTemplate = true
        button.toolTip = "Dyland"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(title: "Open Settings…", key: ",", action: #selector(handleOpenSettings)))
        menu.addItem(.separator())
        menu.addItem(item(title: "Show Notch", key: "", action: #selector(handleShowNotch)))
        menu.addItem(item(title: "Hide Notch", key: "", action: #selector(handleHideNotch)))
        menu.addItem(.separator())
        menu.addItem(item(title: "Clear File Shelf", key: "", action: #selector(handleClearShelf)))
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit Dyland", key: "q", action: #selector(handleQuit)))
        return menu
    }

    private func item(title: String, key: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func handleOpenSettings() { actions.openSettings() }
    @objc private func handleShowNotch() { actions.showNotch() }
    @objc private func handleHideNotch() { actions.hideNotch() }
    @objc private func handleClearShelf() { actions.clearFileShelf() }
    @objc private func handleQuit() { actions.quit() }
}

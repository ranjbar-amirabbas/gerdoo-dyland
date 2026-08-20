import SwiftUI

struct SettingsRootView: View {

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ModulesSettingsPane()
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            AppearanceSettingsPane()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 460)
    }
}

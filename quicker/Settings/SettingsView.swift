import SwiftUI

struct SettingsView: View {
    @State private var tab: String = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView()
                .tabItem { Text("通用") }
                .tag("general")
            ClipboardSettingsView()
                .tabItem { Text("剪切板") }
                .tag("clipboard")
            AboutView()
                .tabItem { Text("关于") }
                .tag("about")
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }
}


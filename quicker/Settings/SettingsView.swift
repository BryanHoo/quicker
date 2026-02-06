import SwiftUI

struct SettingsView: View {
    private enum Tab: String, Hashable {
        case general
        case clipboard
        case textBlock
        case about
    }

    @State private var tab: Tab = .general

    var body: some View {
        TabView(selection: $tab) {
            SettingsPage {
                GeneralSettingsView()
            }
            .tabItem { Label("通用", systemImage: "gearshape") }
            .tag(Tab.general)

            SettingsPage {
                ClipboardSettingsView()
            }
            .tabItem { Label("剪切板", systemImage: "doc.on.clipboard") }
            .tag(Tab.clipboard)

            SettingsPage {
                TextBlockSettingsView()
            }
            .tabItem { Label("文本块", systemImage: "text.bubble") }
            .tag(Tab.textBlock)

            SettingsPage {
                AboutView()
            }
            .tabItem { Label("关于", systemImage: "info.circle") }
            .tag(Tab.about)
        }
        .frame(width: 720, height: 520)
    }
}

private struct SettingsPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
    }
}

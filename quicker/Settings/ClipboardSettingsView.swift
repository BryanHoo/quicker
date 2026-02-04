import AppKit
import SwiftUI

struct ClipboardSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var maxHistoryCount: Int = PreferencesKeys.maxHistoryCount.defaultValue
    @State private var dedupeAdjacentEnabled: Bool = PreferencesKeys.dedupeAdjacentEnabled.defaultValue
    @State private var ignoredApps: [IgnoredApp] = []
    @State private var isConfirmingClearHistory = false

    var body: some View {
        Form {
            Section("历史") {
                Stepper(value: $maxHistoryCount, in: 0...5000, step: 10) {
                    Text("最大历史条数：\(maxHistoryCount)")
                }
                Toggle("相邻去重", isOn: $dedupeAdjacentEnabled)
                Button("立即保存") { save() }
            }

            Section("忽略应用") {
                Button("选择应用…") { pickApp() }
                List {
                    ForEach(ignoredApps, id: \.bundleIdentifier) { app in
                        HStack(spacing: 8) {
                            if let path = app.appPath {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName ?? app.bundleIdentifier)
                                Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteApps)
                }
                .frame(height: 140)
            }

            Section("隐私与权限") {
                Text("应用会读取剪贴板用于历史功能；可通过忽略应用/限量/清空降低暴露面。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("打开“辅助功能”系统设置") {
                    SystemSettingsDeepLink.openAccessibilityPrivacy()
                }
            }

            Section("危险操作") {
                Button("清空历史") { isConfirmingClearHistory = true }
                    .foregroundStyle(.red)
                    .confirmationDialog("确认清空所有历史？", isPresented: $isConfirmingClearHistory) {
                        Button("清空", role: .destructive) {
                            try? appState.clipboardStore.clear()
                            appState.refreshPanelEntries()
                        }
                        Button("取消", role: .cancel) {}
                    }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        maxHistoryCount = appState.preferences.maxHistoryCount
        dedupeAdjacentEnabled = appState.preferences.dedupeAdjacentEnabled
        ignoredApps = appState.ignoreAppStore.all()
    }

    private func save() {
        appState.preferences.maxHistoryCount = maxHistoryCount
        appState.preferences.dedupeAdjacentEnabled = dedupeAdjacentEnabled
        try? appState.clipboardStore.trimToMaxCount()
        appState.refreshPanelEntries()
    }

    private func pickApp() {
        guard
            let url = OpenPanelAppPicker.pickAppUrl(),
            let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier
        else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String

        try? appState.ignoreAppStore.add(bundleIdentifier: bundleId, displayName: name, appPath: url.path)
        ignoredApps = appState.ignoreAppStore.all()
    }

    private func deleteApps(at offsets: IndexSet) {
        for i in offsets {
            appState.ignoreAppStore.remove(bundleIdentifier: ignoredApps[i].bundleIdentifier)
        }
        ignoredApps = appState.ignoreAppStore.all()
    }
}


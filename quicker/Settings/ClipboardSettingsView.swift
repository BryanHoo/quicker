import AppKit
import SwiftUI

struct ClipboardSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var maxHistoryCount: Int = PreferencesKeys.maxHistoryCount.defaultValue
    @State private var dedupeAdjacentEnabled: Bool = PreferencesKeys.dedupeAdjacentEnabled.defaultValue
    @State private var ignoredApps: [IgnoredApp] = []
    @State private var ignoredSelection = Set<String>()
    @State private var isConfirmingClearHistory = false

    var body: some View {
        Form {
            Section("历史") {
                LabeledContent("最大条数") {
                    HStack(spacing: 8) {
                        Text("\(maxHistoryCount)")
                            .monospacedDigit()
                            .frame(minWidth: 44, alignment: .trailing)

                        Stepper("", value: $maxHistoryCount, in: 0...5000, step: 10)
                            .labelsHidden()
                            .accessibilityLabel("最大条数")
                            .accessibilityValue("\(maxHistoryCount)")
                    }
                    .frame(maxWidth: 180, alignment: .trailing)
                }

                Toggle("相邻去重", isOn: $dedupeAdjacentEnabled)

                Text("修改会立即生效：会自动裁剪到最新 N 条。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("隐私与权限") {
                Text("应用会读取剪贴板用于历史功能；可通过忽略应用/限量/清空降低暴露面。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("打开“辅助功能”系统设置") {
                    SystemSettingsDeepLink.openAccessibilityPrivacy()
                }
            }


            Section("忽略应用") {
                HStack {
                    Text("不记录这些应用产生的剪贴板内容。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("移除") { removeSelectedApps() }
                        .disabled(ignoredSelection.isEmpty)
                    Button("选择应用…") { pickApp() }
                }

                List(selection: $ignoredSelection) {
                    ForEach(ignoredApps, id: \.bundleIdentifier) { app in
                        IgnoredAppRow(app: app)
                            .tag(app.bundleIdentifier)
                            .contextMenu {
                                Button("移除") { removeApp(bundleIdentifier: app.bundleIdentifier) }
                            }
                    }
                    .onDelete(perform: deleteApps)
                }
                .listStyle(.inset)
                .frame(height: 160)
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
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: maxHistoryCount) { _ in
            appState.preferences.maxHistoryCount = maxHistoryCount
            try? appState.clipboardStore.trimToMaxCount()
            appState.refreshPanelEntries()
        }
        .onChange(of: dedupeAdjacentEnabled) { _ in
            appState.preferences.dedupeAdjacentEnabled = dedupeAdjacentEnabled
        }
    }

    private func load() {
        maxHistoryCount = appState.preferences.maxHistoryCount
        dedupeAdjacentEnabled = appState.preferences.dedupeAdjacentEnabled
        ignoredApps = appState.ignoreAppStore.all()
        ignoredSelection.removeAll()
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
        ignoredSelection.removeAll()
    }

    private func deleteApps(at offsets: IndexSet) {
        for i in offsets {
            appState.ignoreAppStore.remove(bundleIdentifier: ignoredApps[i].bundleIdentifier)
        }
        ignoredApps = appState.ignoreAppStore.all()
        ignoredSelection.removeAll()
    }

    private func removeSelectedApps() {
        for bundleId in ignoredSelection {
            appState.ignoreAppStore.remove(bundleIdentifier: bundleId)
        }
        ignoredApps = appState.ignoreAppStore.all()
        ignoredSelection.removeAll()
    }

    private func removeApp(bundleIdentifier: String) {
        appState.ignoreAppStore.remove(bundleIdentifier: bundleIdentifier)
        ignoredApps = appState.ignoreAppStore.all()
        ignoredSelection.removeAll()
    }
}

private struct IgnoredAppRow: View {
    let app: IgnoredApp

    var body: some View {
        HStack(spacing: 10) {
            AppIcon(path: app.appPath)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName ?? app.bundleIdentifier)
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct AppIcon: View {
    let path: String?

    var body: some View {
        Group {
            if let path {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

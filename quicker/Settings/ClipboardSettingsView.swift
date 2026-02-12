import AppKit
import SwiftUI

struct ClipboardSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var maxHistoryCount: Int = PreferencesKeys.maxHistoryCount.defaultValue
    @State private var dedupeAdjacentEnabled: Bool = PreferencesKeys.dedupeAdjacentEnabled.defaultValue
    @State private var ignoredApps: [IgnoredApp] = []
    @State private var isConfirmingClearHistory = false

    var body: some View {
        SettingsStack {
            SettingsSection("历史") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最大条数")
                        Text("超出后自动清理更旧的记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    HStack(spacing: 8) {
                        Text("\(maxHistoryCount)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 44, alignment: .trailing)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.11))
                            )

                        Stepper("", value: $maxHistoryCount, in: 0...5000, step: 10)
                            .labelsHidden()
                            .accessibilityLabel("最大条数")
                            .accessibilityValue("\(maxHistoryCount)")
                    }
                    .frame(maxWidth: 180, alignment: .trailing)
                }

                Divider()

                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("相邻去重")
                        Text("连续复制相同内容时只保留一条。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    Toggle("", isOn: $dedupeAdjacentEnabled)
                        .labelsHidden()
                }
            }

            SettingsSection("忽略应用") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已忽略应用")
                        Text("来自这些应用的复制内容不会被记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    HStack(spacing: 8) {
                        Text(ignoredApps.isEmpty ? "未添加" : "\(ignoredApps.count) 个")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.secondary.opacity(0.88))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.secondary.opacity(0.12))
                            )
                        Button("选择应用…") { pickApp() }
                            .buttonStyle(.bordered)
                    }
                }

                if ignoredApps.isEmpty {
                    Label("暂无忽略应用", systemImage: "tray")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    Divider()

                    VStack(spacing: 0) {
                        ForEach(Array(ignoredApps.enumerated()), id: \.element.bundleIdentifier) { index, app in
                            SettingsRow {
                                IgnoredAppRow(app: app)
                            } trailing: {
                                Button {
                                    removeApp(bundleIdentifier: app.bundleIdentifier)
                                } label: {
                                    Label("移除", systemImage: "minus.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("移除")
                            }

                            if index < ignoredApps.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            SettingsSection("危险操作") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("历史记录")
                        Text("此操作不可撤销，请谨慎执行。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    Button("清空历史") { isConfirmingClearHistory = true }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .confirmationDialog("确认清空所有历史？", isPresented: $isConfirmingClearHistory) {
                            Button("清空", role: .destructive) {
                                try? appState.clipboardStore.clear()
                                appState.refreshPanelEntries()
                            }
                            Button("取消", role: .cancel) {}
                        }
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: maxHistoryCount) { _, newValue in
            appState.preferences.maxHistoryCount = newValue
            try? appState.clipboardStore.trimToMaxCount()
            appState.refreshPanelEntries()
        }
        .onChange(of: dedupeAdjacentEnabled) { _, newValue in
            appState.preferences.dedupeAdjacentEnabled = newValue
        }
    }

    private func load() {
        maxHistoryCount = appState.preferences.maxHistoryCount
        dedupeAdjacentEnabled = appState.preferences.dedupeAdjacentEnabled
        ignoredApps = appState.ignoreAppStore.all()
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

    private func removeApp(bundleIdentifier: String) {
        appState.ignoreAppStore.remove(bundleIdentifier: bundleIdentifier)
        ignoredApps = appState.ignoreAppStore.all()
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

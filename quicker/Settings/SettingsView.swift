import AppKit
import SwiftUI

struct SettingsView: View {
    private enum Tab: String, Hashable, CaseIterable, Identifiable {
        case general
        case clipboard
        case textBlock
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                return "通用"
            case .clipboard:
                return "剪切板"
            case .textBlock:
                return "文本块"
            case .about:
                return "关于"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "快捷键、启动与权限"
            case .clipboard:
                return "历史记录、忽略应用"
            case .textBlock:
                return "模板文本管理"
            case .about:
                return "版本信息与应用说明"
            }
        }

        var symbolName: String {
            switch self {
            case .general:
                return "gearshape"
            case .clipboard:
                return "doc.on.clipboard"
            case .textBlock:
                return "text.bubble"
            case .about:
                return "info.circle"
            }
        }
    }

    @State private var tab: Tab = .general
    @Environment(\.colorScheme) private var colorScheme

    private var palette: SettingsPalette {
        SettingsTheme.palette(for: colorScheme)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1)
                .overlay {
                    Rectangle()
                        .fill(palette.separatorShadow)
                        .frame(width: 1)
                        .offset(x: 1)
                }

            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 1)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(palette.separatorShadow)
                            .frame(height: 1)
                    }

                SettingsPage {
                    selectedPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(SettingsWindowBackground(palette: palette).ignoresSafeArea(.container, edges: .top))
        .clipShape(RoundedRectangle(cornerRadius: SettingsTheme.windowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsTheme.windowCornerRadius, style: .continuous)
                .stroke(palette.windowBorder, lineWidth: 1)
        )
        .frame(width: 820, height: 560)
        .background(SettingsWindowConfigurator())
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.60),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Quicker")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("设置面板")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 36)
            .padding(.horizontal, 18)

            VStack(spacing: 8) {
                ForEach(Tab.allCases) { item in
                    SettingsSidebarButton(
                        title: item.title,
                        subtitle: item.subtitle,
                        symbolName: item.symbolName,
                        isSelected: item == tab,
                        palette: palette
                    ) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            tab = item
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 10)

            Label("偏好设置", systemImage: "sparkles")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.82))
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .frame(width: 246)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsSidebarBackground(palette: palette))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(tab.title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(tab.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch tab {
        case .general:
            GeneralSettingsView()
        case .clipboard:
            ClipboardSettingsView()
        case .textBlock:
            TextBlockSettingsView()
        case .about:
            AboutView()
        }
    }
}

private struct SettingsSidebarButton: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let isSelected: Bool
    let palette: SettingsPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? palette.selectedIconBackground : Color.clear)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? palette.selectedItemBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(isSelected ? palette.selectedItemBorder : Color.clear, lineWidth: 1)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsWindowBackground: View {
    let palette: SettingsPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SettingsTheme.windowCornerRadius, style: .continuous)
                .fill(palette.windowBackground)

            LinearGradient(
                colors: [
                    palette.windowOverlayTop,
                    palette.windowOverlayBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: SettingsTheme.windowCornerRadius, style: .continuous))

            RadialGradient(
                colors: [palette.windowGlow, .clear],
                center: .topLeading,
                startRadius: 8,
                endRadius: 300
            )
            .clipShape(RoundedRectangle(cornerRadius: SettingsTheme.windowCornerRadius, style: .continuous))
        }
    }
}

private struct SettingsSidebarBackground: View {
    let palette: SettingsPalette

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: SettingsTheme.windowCornerRadius,
            bottomLeadingRadius: SettingsTheme.windowCornerRadius,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous
        )

        shape
            .fill(palette.sidebarBackground)
            .overlay(
                LinearGradient(
                    colors: [
                        palette.sidebarOverlayTop,
                        palette.sidebarOverlayBottom,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
            )
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
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
    }
}

struct SettingsStack<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsTheme.sectionSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }
}

struct SettingsSection<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .settingsModuleCard()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, 8)
        .frame(minHeight: 36, alignment: .center)
    }
}

struct SettingsCardContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = SettingsTheme.palette(for: colorScheme)

        content
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.cardCornerRadius, style: .continuous)
                    .fill(palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: SettingsTheme.cardCornerRadius, style: .continuous)
                            .stroke(palette.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: palette.cardAmbientShadow, radius: 9, x: 0, y: 0)
                    .shadow(color: palette.cardDropShadow, radius: 2, x: 0, y: 1)
            )
    }
}

extension View {
    func settingsCardContainer() -> some View {
        modifier(SettingsCardContainerModifier())
    }

    func settingsModuleCard() -> some View {
        settingsCardContainer()
            .padding(.horizontal, SettingsTheme.cardOuterInset)
            .padding(.vertical, 1)
    }
}

enum SettingsTheme {
    static let windowCornerRadius: CGFloat = 22
    static let cardCornerRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 18
    static let cardOuterInset: CGFloat = 6

    static func palette(for colorScheme: ColorScheme) -> SettingsPalette {
        if colorScheme == .dark {
            return SettingsPalette(
                windowBackground: Color(nsColor: .windowBackgroundColor),
                windowOverlayTop: Color.white.opacity(0.07),
                windowOverlayBottom: Color.white.opacity(0.01),
                windowGlow: Color.accentColor.opacity(0.14),
                windowBorder: Color.white.opacity(0.12),
                windowShadow: Color.black.opacity(0.34),
                sidebarBackground: Color(nsColor: .controlBackgroundColor).opacity(0.72),
                sidebarOverlayTop: Color.white.opacity(0.05),
                sidebarOverlayBottom: Color.black.opacity(0.08),
                separator: Color.white.opacity(0.11),
                separatorShadow: Color.black.opacity(0.30),
                selectedItemBackground: Color.accentColor.opacity(0.18),
                selectedItemBorder: Color.accentColor.opacity(0.36),
                selectedIconBackground: Color.accentColor.opacity(0.20),
                chipBackground: Color.white.opacity(0.09),
                cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.86),
                cardBorder: Color.white.opacity(0.12),
                cardAmbientShadow: Color.black.opacity(0.10),
                cardDropShadow: Color.black.opacity(0.12)
            )
        }

        return SettingsPalette(
            windowBackground: Color(nsColor: .windowBackgroundColor),
            windowOverlayTop: Color.white.opacity(0.40),
            windowOverlayBottom: Color.white.opacity(0.12),
            windowGlow: Color.accentColor.opacity(0.07),
            windowBorder: Color.black.opacity(0.06),
            windowShadow: Color.black.opacity(0.12),
            sidebarBackground: Color(nsColor: .controlBackgroundColor).opacity(0.82),
            sidebarOverlayTop: Color.white.opacity(0.22),
            sidebarOverlayBottom: Color.white.opacity(0.06),
            separator: Color.black.opacity(0.08),
            separatorShadow: Color.white.opacity(0.16),
            selectedItemBackground: Color.accentColor.opacity(0.13),
            selectedItemBorder: Color.accentColor.opacity(0.24),
            selectedIconBackground: Color.accentColor.opacity(0.16),
            chipBackground: Color.accentColor.opacity(0.11),
            cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.88),
            cardBorder: Color.black.opacity(0.07),
            cardAmbientShadow: Color.black.opacity(0.028),
            cardDropShadow: Color.black.opacity(0.04)
        )
    }
}

struct SettingsPalette {
    let windowBackground: Color
    let windowOverlayTop: Color
    let windowOverlayBottom: Color
    let windowGlow: Color
    let windowBorder: Color
    let windowShadow: Color
    let sidebarBackground: Color
    let sidebarOverlayTop: Color
    let sidebarOverlayBottom: Color
    let separator: Color
    let separatorShadow: Color
    let selectedItemBackground: Color
    let selectedItemBorder: Color
    let selectedIconBackground: Color
    let chipBackground: Color
    let cardBackground: Color
    let cardBorder: Color
    let cardAmbientShadow: Color
    let cardDropShadow: Color
}

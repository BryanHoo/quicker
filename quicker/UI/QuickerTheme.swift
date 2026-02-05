import SwiftUI

enum QuickerTheme {
    enum ClipboardPanel {
        // MARK: Metrics

        static let size = CGSize(width: 420, height: 276)
        static let cornerRadius: CGFloat = 16
        static let containerPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 10

        // MARK: Typography

        static let headerFont: Font = .system(size: 14, weight: .semibold)
        static let rowTextFont: Font = .system(size: 13)
        static let rowCommandFont: Font = .system(size: 11, weight: .medium, design: .monospaced)
        static let hintSymbolFont: Font = .system(size: 11, weight: .medium, design: .monospaced)
        static let hintTextFont: Font = .system(size: 11)
        static let pageLabelFont: Font = .system(size: 11, weight: .medium, design: .monospaced)

        // MARK: Colors / Opacity Tokens

        static let borderOpacity: Double = 0.12
        static let dividerOpacity: Double = 0.08
        static let keyCapBackgroundOpacity: Double = 0.22
        static let keyCapBorderOpacity: Double = 0.08
        static let pagePillBackgroundOpacity: Double = 0.22
        static let selectedFillOpacity: Double = 0.18
        static let selectedBorderOpacity: Double = 0.20

        // MARK: Shadow

        static let shadowOpacity: Double = 0.22
        static let shadowRadius: CGFloat = 18
        static let shadowOffset = CGSize(width: 0, height: 10)

        // MARK: Background

        static var background: some View {
            ClipboardPanelBackground()
        }

        private struct ClipboardPanelBackground: View {
            @Environment(\.colorScheme) private var colorScheme

            var body: some View {
                let radius = QuickerTheme.ClipboardPanel.cornerRadius
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.thickMaterial)

                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.30 : 0.22),
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.10),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                    RadialGradient(
                        colors: [Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10), Color.clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 260
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                    RadialGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.18 : 0.16), Color.clear],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 240
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

                    if colorScheme == .dark {
                        RadialGradient(
                            colors: [Color.white.opacity(0.10), Color.clear],
                            center: .bottom,
                            startRadius: 10,
                            endRadius: 280
                        )
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
            }
        }
    }
}

import AppKit

protocol FrontmostAppProviding {
    var frontmostBundleIdentifier: String? { get }
}

struct SystemFrontmostAppProvider: FrontmostAppProviding {
    var frontmostBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}


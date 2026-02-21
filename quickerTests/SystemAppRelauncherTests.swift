import XCTest
@testable import quicker

final class SystemAppRelauncherTests: XCTestCase {
    func testRelaunchDoesNotTerminateWhenLauncherFails() {
        let launcher = SpyRelaunchProcessLauncher(result: false)
        let terminator = SpyApplicationTerminator()
        let sut = SystemAppRelauncher(
            launcher: launcher,
            terminator: terminator,
            bundlePath: "/Applications/Quicker.app"
        )

        sut.relaunch()

        XCTAssertEqual(launcher.launchedBundlePaths, ["/Applications/Quicker.app"])
        XCTAssertEqual(terminator.terminateCount, 0)
    }

    func testRelaunchTerminatesWhenLauncherSucceeds() {
        let launcher = SpyRelaunchProcessLauncher(result: true)
        let terminator = SpyApplicationTerminator()
        let sut = SystemAppRelauncher(
            launcher: launcher,
            terminator: terminator,
            bundlePath: "/Applications/Quicker.app"
        )

        sut.relaunch()

        XCTAssertEqual(launcher.launchedBundlePaths, ["/Applications/Quicker.app"])
        XCTAssertEqual(terminator.terminateCount, 1)
    }
}

private final class SpyRelaunchProcessLauncher: AppRelaunchProcessLaunching {
    private let result: Bool
    private(set) var launchedBundlePaths: [String] = []

    init(result: Bool) {
        self.result = result
    }

    func launchNewInstance(bundlePath: String) -> Bool {
        launchedBundlePaths.append(bundlePath)
        return result
    }
}

private final class SpyApplicationTerminator: ApplicationTerminating {
    private(set) var terminateCount = 0

    func terminate() {
        terminateCount += 1
    }
}

import Carbon
import XCTest
@testable import quicker

final class HotkeyRouteCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() {
        for action in HotkeyAction.allCases {
            let id = HotkeyRouteCodec.makeID(for: action)
            XCTAssertEqual(id.signature, HotkeyRouteCodec.signature)
            XCTAssertEqual(HotkeyRouteCodec.decode(id), action)
        }
    }

    func testDecodeRejectsUnknownSignature() {
        let id = EventHotKeyID(signature: OSType(0x44454144), id: HotkeyAction.clipboardPanel.rawValue)
        XCTAssertNil(HotkeyRouteCodec.decode(id))
    }
}

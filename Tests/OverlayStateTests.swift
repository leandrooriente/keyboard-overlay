import XCTest
@testable import KeyboardOverlay

final class OverlayStateTests: XCTestCase {
    func testHardwareLayersRestoreManualSelectionAndKeepHeldKeysLit() async throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        await MainActor.run {
            let state = OverlayState(layout: layout, persistsSelection: false)
            state.select(0)
            state.setMoonlanderConnected(true)
            state.recordPhysicalKey("R2-2", pressed: true)
            state.followHardwareLayer(1)
            XCTAssertEqual(state.selectedLayer, 1)
            XCTAssertEqual(state.pressedKeys, ["R2-2"])
            state.followHardwareLayer(2)
            XCTAssertEqual(state.selectedLayer, 2)
            state.followHardwareLayer(0)
            state.recordPhysicalKey("R2-2", pressed: false)
            XCTAssertEqual(state.selectedLayer, 0)
            XCTAssertTrue(state.pressedKeys.isEmpty)
            state.select(1)
            state.followHardwareLayer(2)
            state.followHardwareLayer(0)
            XCTAssertEqual(state.selectedLayer, 1)
        }
    }

    func testPhysicalEventsAvoidAmbiguousHostMatchesAndClearOnDisconnect() async throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        await MainActor.run {
            let state = OverlayState(layout: layout, persistsSelection: false)
            state.select(0)
            state.setMoonlanderConnected(true)
            state.recordPhysicalKey("RT1", pressed: true)
            state.recordKeyEvent(.keyDown, keyCode: 51, modifiers: [])
            XCTAssertEqual(state.pressedKeys, ["RT1"])
            state.clearHostPressedKeys()
            XCTAssertEqual(state.pressedKeys, ["RT1"])
            state.followHardwareLayer(2)
            state.setMoonlanderConnected(false)
            XCTAssertEqual(state.selectedLayer, 0)
            XCTAssertTrue(state.pressedKeys.isEmpty)
            state.recordKeyEvent(.keyDown, keyCode: 0, modifiers: [])
            XCTAssertEqual(state.pressedKeys, ["L2-1"])
            state.clearPressedKeys()
            XCTAssertTrue(state.pressedKeys.isEmpty)
        }
    }
}

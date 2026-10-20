import AppKit
import XCTest
@testable import KeyboardOverlay

final class KeyTrackingTests: XCTestCase {
    private func layout() throws -> KeyboardLayout {
        try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
    }

    func testChordsReleaseAndRepeatsTrackEachKeyOnce() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.keyDown(keyCode: 0, modifiers: [.command])
        tracker.keyDown(keyCode: 0)
        tracker.keyDown(keyCode: 1)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L2-1", "L2-2"])
        tracker.keyUp(keyCode: 0)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L2-2"])
        tracker.keyUp(keyCode: 1)
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
    }

    func testShiftedPunctuationPrefersDedicatedKeyAndRetainsDownFlags() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.keyDown(keyCode: 25, modifiers: [.shift])
        tracker.keyDown(keyCode: 25)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L2-6"])
        tracker.keyUp(keyCode: 25)
        tracker.keyDown(keyCode: 25)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["R0-4"])
        tracker.reset()
        tracker.keyDown(keyCode: 18, modifiers: [.shift])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L0-1"])
    }

    func testNumpadAndTopRowDigitsRemainDistinct() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.keyDown(keyCode: 83)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 2), ["R3-1"])
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
        tracker.reset()
        tracker.keyDown(keyCode: 18)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 2), ["L0-1"])
        tracker.reset()
        tracker.keyDown(keyCode: 82)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 2), ["R4-2"])
        tracker.reset()
        tracker.keyDown(keyCode: 29)
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 2).isEmpty)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["R0-5"])
    }

    func testDisplayedLayerOverridesAndInheritedDualRoleLegends() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.keyDown(keyCode: 12)
        tracker.keyDown(keyCode: 3)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 2), ["L1-1", "L2-4"])
        tracker.reset()
        tracker.keyDown(keyCode: 122)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 1), ["L0-1"])
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
        tracker.reset()
        tracker.keyDown(keyCode: 19)
        // Layer 1 has an F2 override and a firmware-only layer toggle labelled 2.
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 1).isEmpty)
    }

    func testSideSpecificModifiersAndOverlappingShiftRelease() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.flagsChanged(keyCode: 56, modifiers: [.shift])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L3-0"])
        tracker.flagsChanged(keyCode: 60, modifiers: [.shift])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L3-0", "R3-6"])
        tracker.flagsChanged(keyCode: 56, modifiers: [.shift])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["R3-6"])
        tracker.flagsChanged(keyCode: 60, modifiers: [])
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
        tracker.flagsChanged(keyCode: 59, modifiers: [.control])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L4-2"])
    }

    func testDeviceModifierMasksHandleBothSidesWithoutTogglingHeldSide() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.flagsChanged(keyCode: 56, modifiers: NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x2))
        tracker.flagsChanged(keyCode: 60, modifiers: NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x6))
        tracker.flagsChanged(keyCode: 56, modifiers: NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | 0x4))
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["R3-6"])
        tracker.reset()
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
    }

    func testDuplicateBackspacesHighlightBothPossibleSources() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.keyDown(keyCode: 51)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["R0-6", "RT1"])
        tracker.reset()
        tracker.keyDown(keyCode: 49)
        tracker.keyDown(keyCode: 36)
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["LT1", "RT2"])
    }

    func testFirmwareShiftedPunctuationReleasesWithoutStickyHighlights() throws {
        let layout = try layout()
        var tracker = KeyPressTracker()
        tracker.flagsChanged(keyCode: 56, modifiers: [.shift])
        tracker.keyDown(keyCode: 25, modifiers: [.shift])
        XCTAssertEqual(tracker.highlightedKeys(layout: layout, layer: 0), ["L3-0", "L2-6"])
        tracker.keyUp(keyCode: 25)
        tracker.flagsChanged(keyCode: 56, modifiers: [])
        XCTAssertTrue(tracker.highlightedKeys(layout: layout, layer: 0).isEmpty)
    }
}

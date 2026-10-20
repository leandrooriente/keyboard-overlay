import XCTest
@testable import KeyboardOverlay

final class LayoutTests: XCTestCase {
    func testBundledLayoutCoversEveryPhysicalKey() throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        try layout.validate()
        XCTAssertEqual(KeyGeometry.all.count, 72)
        XCTAssertEqual(Set(KeyGeometry.all.map(\.id)).count, 72)
        XCTAssertEqual(layout.layers[0].keys.count, 72)
    }

    func testLayerOverridesAndTransparentInheritance() throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        XCTAssertEqual(layout.legend(for: "L0-1", layer: 1).label, "F1")
        XCTAssertEqual(layout.legend(for: "R1-1", layer: 2).label, "7")
        XCTAssertEqual(layout.legend(for: "L1-1", layer: 2).label, "Q")
        XCTAssertTrue(layout.isInherited("L1-1", layer: 2))
        XCTAssertFalse(layout.isInherited("R1-1", layer: 2))
        XCTAssertEqual(layout.legend(for: "L2-4", layer: 0).holdLayer, 2)
    }

    func testShiftedLegendsAreExplicitAndRespectLayerOverrides() throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        let expected = [
            "L0-1": "!", "L0-2": "@", "L0-3": "#", "L0-4": "$", "L0-5": "%", "L0-6": "_",
            "L1-6": "{", "L2-0": "~",
            "R0-0": "+", "R0-1": "^", "R0-2": "&", "R0-3": "*", "R0-4": "(", "R0-5": ")",
            "R1-0": "}", "R1-6": "|", "R2-5": ":", "R2-6": "\"",
            "R3-3": "<", "R3-4": ">", "R3-5": "?",
        ]

        // Only the 21 US number/punctuation keys receive a second legend. This also
        // excludes letters and the dedicated, already-shifted literal ( and ) keys.
        for (id, legend) in layout.layers[0].keys {
            XCTAssertEqual(legend.shifted, expected[id], "Unexpected base Shift legend for \(id)")
        }
        for (id, shifted) in expected {
            XCTAssertEqual(layout.legend(for: id, layer: 0).shifted, shifted, id)
        }

        for layer in layout.layers.dropFirst() {
            for id in layout.layers[0].keys.keys {
                if layer.keys[id] == nil {
                    XCTAssertEqual(layout.legend(for: id, layer: layer.id).shifted, expected[id],
                                   "Inherited key \(id) lost its Shift legend on layer \(layer.id)")
                } else {
                    // A whole legend override must clear base metadata, including
                    // when a punctuation key becomes a numpad, function, or media key.
                    XCTAssertNil(layout.legend(for: id, layer: layer.id).shifted,
                                 "Override \(id) inherited a Shift legend on layer \(layer.id)")
                }
            }
        }
    }

    func testRoutesValidateExternalLayerInput() {
        XCTAssertEqual(OverlayRoute(url: URL(string: "keyboard-overlay://show?layer=2")!), .show(2))
        XCTAssertEqual(OverlayRoute(url: URL(string: "keyboard-overlay://show")!), .show(nil))
        XCTAssertEqual(OverlayRoute(url: URL(string: "keyboard-overlay://hide")!), .hide)
        XCTAssertNil(OverlayRoute(url: URL(string: "keyboard-overlay://show?layer=3")!))
        XCTAssertNil(OverlayRoute(url: URL(string: "keyboard-overlay://show?layer=wrong")!))
        XCTAssertNil(OverlayRoute(url: URL(string: "https://show?layer=0")!))
    }

    func testInvalidCustomDataDoesNotSilentlyFallBack() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try KeyboardLayout.load(overrideURL: url))
    }
}

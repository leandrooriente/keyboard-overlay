import XCTest
@testable import KeyboardOverlay

final class MoonlanderMatrixTests: XCTestCase {
    func testMatrixCoversEveryPhysicalKeyExactlyOnce() {
        let mapped = (0..<12).flatMap { row in
            (0..<7).compactMap { column in MoonlanderMatrix.keyID(row: row, column: column) }
        }
        XCTAssertEqual(mapped.count, 72)
        XCTAssertEqual(Set(mapped).count, 72)
        XCTAssertEqual(Set(mapped), Set(KeyGeometry.all.map(\.id)))
    }

    func testHomeRowLayerKeysUsePhysicalCoordinates() throws {
        let layout = try KeyboardLayout.load(overrideURL: URL(fileURLWithPath: "/nonexistent-layout.json"))
        let f = try XCTUnwrap(MoonlanderMatrix.keyID(row: 2, column: 4))
        let j = try XCTUnwrap(MoonlanderMatrix.keyID(row: 8, column: 2))
        XCTAssertEqual(f, "L2-4")
        XCTAssertEqual(j, "R2-2")
        XCTAssertEqual(layout.legend(for: f, layer: 0).holdLayer, 2)
        XCTAssertEqual(layout.legend(for: j, layer: 0).holdLayer, 1)
    }

    func testRightHandColumnsAreNotMirroredAndBackspacesRemainDistinct() {
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 6, column: 0), "R0-0")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 6, column: 6), "R0-6")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 11, column: 5), "RT1")
        XCTAssertNotEqual(MoonlanderMatrix.keyID(row: 6, column: 6),
                          MoonlanderMatrix.keyID(row: 11, column: 5))
    }

    func testThumbClustersFollowVisualKeyIDs() {
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 5, column: 3), "LT0")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 5, column: 0), "LT1")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 5, column: 1), "LT2")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 5, column: 2), "LT3")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 11, column: 3), "RT0")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 11, column: 5), "RT1")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 11, column: 6), "RT2")
        XCTAssertEqual(MoonlanderMatrix.keyID(row: 11, column: 4), "RT3")
    }

    func testHolesAndOutOfRangeCoordinatesHaveNoKey() {
        let holes = [(3, 6), (4, 5), (4, 6), (5, 4), (5, 5), (5, 6),
                     (9, 0), (10, 0), (10, 1), (11, 0), (11, 1), (11, 2)]
        for (row, column) in holes {
            XCTAssertNil(MoonlanderMatrix.keyID(row: row, column: column))
        }
        for (row, column) in [(-1, 0), (12, 0), (0, -1), (0, 7), (255, 255)] {
            XCTAssertNil(MoonlanderMatrix.keyID(row: row, column: column))
        }
    }
}

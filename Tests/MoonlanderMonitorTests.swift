import XCTest
@testable import KeyboardOverlay

final class MoonlanderMonitorTests: XCTestCase {
    private func frame(_ prefix: [UInt8]) -> [UInt8] {
        prefix + [UInt8](repeating: 0, count: 32 - prefix.count)
    }

    func testParsesCurrentAndPreviousOryxProtocolVersions() {
        XCTAssertEqual(MoonlanderReport(bytes: frame([0xFE, 4, 0xFE])), .protocolVersion(4))
        XCTAssertEqual(MoonlanderReport(bytes: frame([0xFE, 5, 0xFE])), .protocolVersion(5))
        XCTAssertEqual(MoonlanderReport(bytes: frame([0x04, 0xFE])), .paired)
    }

    func testLayerReportsIncludeReturnOnHoldRelease() {
        let reports = [0, 1, 0, 2, 0].map { layer in
            MoonlanderReport(bytes: frame([0x05, UInt8(layer), 0xFE]))
        }
        XCTAssertEqual(reports, [.layer(0), .layer(1), .layer(0), .layer(2), .layer(0)])
    }

    func testPhysicalReportsPreserveColumnRowOrderAndRelease() {
        XCTAssertEqual(MoonlanderReport(bytes: frame([0x06, 2, 8, 0xFE])), .key(row: 8, column: 2, pressed: true))
        XCTAssertEqual(MoonlanderReport(bytes: frame([0x07, 2, 8, 0xFE])), .key(row: 8, column: 2, pressed: false))
    }

    func testRejectsMalformedTruncatedAndUnknownReports() {
        XCTAssertNil(MoonlanderReport(bytes: [0x05, 1, 0xFE]))
        XCTAssertNil(MoonlanderReport(bytes: frame([0x05, 1, 0])))
        XCTAssertNil(MoonlanderReport(bytes: frame([0x06, 7, 0, 0xFE])))
        XCTAssertNil(MoonlanderReport(bytes: frame([0x07, 0, 12, 0xFE])))
        XCTAssertNil(MoonlanderReport(bytes: frame([0x06, 2, 8, 0])))
        XCTAssertNil(MoonlanderReport(bytes: frame([0x80, 0xFE])))
    }
}

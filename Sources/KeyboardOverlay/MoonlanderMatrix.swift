/// Converts the physical matrix coordinates reported by Oryx RawHID into the
/// overlay's key IDs. Coordinates are independent of keycodes and active layers.
enum MoonlanderMatrix {
    static func keyID(row: Int, column: Int) -> String? {
        guard rows.indices.contains(row), rows[row].indices.contains(column) else { return nil }
        return rows[row][column]
    }

    // ZSA firmware25, LAYOUT in keyboards/zsa/moonlander/reva/keyboard.json:
    // https://github.com/zsa/qmk_firmware/blob/93b2b9ec3368f86c5eb5a2e3f934049f8daef885/keyboards/zsa/moonlander/reva/keyboard.json
    // revb has the same matrix. The right-hand columns already run left-to-right;
    // do not mirror them. Thumb rows are ordered electrically, not visually.
    private static let rows: [[String?]] = [
        ["L0-0", "L0-1", "L0-2", "L0-3", "L0-4", "L0-5", "L0-6"],
        ["L1-0", "L1-1", "L1-2", "L1-3", "L1-4", "L1-5", "L1-6"],
        ["L2-0", "L2-1", "L2-2", "L2-3", "L2-4", "L2-5", "L2-6"],
        ["L3-0", "L3-1", "L3-2", "L3-3", "L3-4", "L3-5", nil],
        ["L4-0", "L4-1", "L4-2", "L4-3", "L4-4", nil, nil],
        ["LT1", "LT2", "LT3", "LT0", nil, nil, nil],
        ["R0-0", "R0-1", "R0-2", "R0-3", "R0-4", "R0-5", "R0-6"],
        ["R1-0", "R1-1", "R1-2", "R1-3", "R1-4", "R1-5", "R1-6"],
        ["R2-0", "R2-1", "R2-2", "R2-3", "R2-4", "R2-5", "R2-6"],
        [nil, "R3-1", "R3-2", "R3-3", "R3-4", "R3-5", "R3-6"],
        [nil, nil, "R4-2", "R4-3", "R4-4", "R4-5", "R4-6"],
        [nil, nil, nil, "RT0", "RT3", "RT1", "RT2"],
    ]
}

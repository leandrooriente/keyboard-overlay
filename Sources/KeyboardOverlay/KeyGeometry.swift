import Foundation

struct KeyGeometry: Identifiable {
    let id: String
    let x: Double
    let y: Double
    var width: Double = 57
    var height: Double = 61
    var rotation: Double = 0

    static let boardWidth: Double = 1234
    static let boardHeight: Double = 520

    static let all: [KeyGeometry] = {
        var result = [KeyGeometry]()
        let stagger: [Double] = [20, 13, 6, 0, 6, 13, 20]
        for side in ["L", "R"] {
            let start: Double = side == "L" ? 0 : 805
            for row in 0...4 {
                for column in 0...6 {
                    if row == 3 && ((side == "L" && column == 6) || (side == "R" && column == 0)) { continue }
                    if row == 4 && ((side == "L" && column > 4) || (side == "R" && column < 2)) { continue }
                    result.append(KeyGeometry(
                        id: "\(side)\(row)-\(column)",
                        x: start + Double(column) * 62 + 28.5,
                        y: 42 + Double(row) * 65 + stagger[column]
                    ))
                }
            }
        }
        result += [
            KeyGeometry(id: "LT0", x: 427, y: 329, width: 112, height: 57, rotation: 30),
            KeyGeometry(id: "LT1", x: 372, y: 391, width: 57, height: 94, rotation: 30),
            KeyGeometry(id: "LT2", x: 427, y: 423, width: 57, height: 94, rotation: 30),
            KeyGeometry(id: "LT3", x: 482, y: 455, width: 57, height: 94, rotation: 30),
            KeyGeometry(id: "RT0", x: 807, y: 329, width: 112, height: 57, rotation: -30),
            KeyGeometry(id: "RT1", x: 807, y: 423, width: 57, height: 94, rotation: -30),
            KeyGeometry(id: "RT2", x: 862, y: 391, width: 57, height: 94, rotation: -30),
            KeyGeometry(id: "RT3", x: 752, y: 455, width: 57, height: 94, rotation: -30),
        ]
        return result
    }()
}

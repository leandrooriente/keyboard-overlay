import SwiftUI

enum Palette {
    static let background = Color(hex: 0x16181C)
    static let surface = Color(hex: 0x1F2228)
    static let border = Color(hex: 0x34383F)
    static let text = Color(hex: 0xEFF0F3)
    static let muted = Color(hex: 0x8D929D)
    static let orange = Color(hex: 0xF3AD7A)
    static let green = Color(hex: 0xADE2AC)
    static let blue = Color(hex: 0x9BCBEE)
    static let purple = Color(hex: 0xC8B4ED)

    static func accent(_ kind: String) -> Color {
        switch kind {
        case "modifier", "function": return green
        case "layer", "number", "media": return blue
        case "macro": return orange
        case "source": return purple
        default: return text
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}

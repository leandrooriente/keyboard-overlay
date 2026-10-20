import AppKit

/// Matches the keys macOS receives to legends in the displayed layer. Firmware-only
/// actions (including layer holds and macros) do not expose a physical key identity.
struct KeyPressTracker {
    private var pressed: [UInt16: NSEvent.ModifierFlags] = [:]
    private var modifiers: Set<UInt16> = []

    mutating func keyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        // Auto-repeat must not replace the Shift state captured by the original down.
        if pressed[keyCode] == nil { pressed[keyCode] = modifiers }
    }

    mutating func keyUp(keyCode: UInt16) {
        pressed.removeValue(forKey: keyCode)
    }

    mutating func flagsChanged(keyCode: UInt16, modifiers flags: NSEvent.ModifierFlags) {
        for group in Self.modifierGroups {
            if !flags.contains(group.flag) {
                modifiers.subtract(group.codes)
            } else if group.codes.contains(keyCode) {
                // Device-dependent flags distinguish releasing one Shift while the
                // other remains held. Some synthetic events omit these bits; their
                // aggregate flag plus the changed key still permits a side toggle.
                let deviceMask = group.deviceMasks.reduce(UInt(0), |)
                if flags.rawValue & deviceMask != 0 {
                    for (code, mask) in zip(group.codes, group.deviceMasks) {
                        if flags.rawValue & mask != 0 { modifiers.insert(code) }
                        else { modifiers.remove(code) }
                    }
                } else if modifiers.contains(keyCode) {
                    modifiers.remove(keyCode)
                } else {
                    modifiers.insert(keyCode)
                }
            }
        }
    }

    mutating func reset() {
        pressed.removeAll()
        modifiers.removeAll()
    }

    func highlightedKeys(layout: KeyboardLayout, layer: Int) -> Set<String> {
        let legends = KeyGeometry.all.map { ($0.id, layout.legend(for: $0.id, layer: layer)) }
        var result: Set<String> = []
        for (code, flags) in pressed {
            result.formUnion(Self.matches(code: code, flags: flags, legends: legends))
        }
        for code in modifiers {
            result.formUnion(legends.compactMap { id, legend in
                Self.matchesModifier(code: code, legend: legend) ? id : nil
            })
        }
        return result
    }

    private static func matches(code: UInt16, flags: NSEvent.ModifierFlags,
                                legends: [(String, KeyLegend)]) -> Set<String> {
        let eligible = legends.filter { _, legend in
            !["macro", "blank", "disabled"].contains(legend.kind) && legend.tapLayer == nil
        }
        if let label = keypad[code] {
            // Keypad digits and operators are separate host keycodes. Prefer the
            // declared number keys, avoiding identically labelled inherited keys.
            let matches = eligible.filter { _, legend in
                normalize(legend.label) == label && isNumpad(legend)
            }
            return Set(matches.map(\.0))
        }
        if let base = printable[code] {
            let eligible = eligible.filter { !isNumpad($0.1) }
            if flags.contains(.shift), let shifted = shifted[base] {
                // QMK's dedicated '(' emits Shift+9 too. A literal keycap is the
                // closest available match; macOS cannot disambiguate those sources.
                let literal = eligible.filter { normalize($0.1.label) == shifted }
                if !literal.isEmpty { return Set(literal.map(\.0)) }
                let shiftedMatches = eligible.filter { $0.1.shifted.map(normalize) == shifted }
                if !shiftedMatches.isEmpty { return Set(shiftedMatches.map(\.0)) }
            }
            let matching = eligible.filter { normalize($0.1.label) == base }
            let plain = matching.filter { $0.1.kind != "layer" || $0.1.holdLayer != nil }
            return Set((plain.isEmpty ? matching : plain).map(\.0))
        }
        guard let token = special[code] else { return [] }
        return Set(eligible.compactMap { id, legend in
            canonicalLabel(legend) == token ? id : nil
        })
    }

    private static func isNumpad(_ legend: KeyLegend) -> Bool {
        let label = normalize(legend.label)
        return legend.kind == "number" || legend.secondary?.lowercased().contains("numpad") == true ||
            (legend.kind == "layer" && legend.holdLayer == nil && legend.tapLayer == nil &&
             !label.isEmpty && label.allSatisfy(\.isNumber))
    }

    private static func normalize(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func canonicalLabel(_ legend: KeyLegend) -> String {
        let label = normalize(legend.label)
        let aliases = ["return": "enter", "↵": "enter", "⏎": "enter", "esc": "escape",
                       "⌫": "backspace", "delete backward": "backspace", "⌦": "delete",
                       "caps lock": "capslock", "page up": "pageup", "page down": "pagedown"]
        return aliases[label] ?? label
    }

    private static func matchesModifier(code: UInt16, legend: KeyLegend) -> Bool {
        guard legend.kind == "modifier" else { return false }
        let label = canonicalLabel(legend)
        let secondary = normalize(legend.secondary ?? "")
        let left = label.contains("left") || secondary == "l" || secondary == "left"
        let right = label.contains("right") || secondary == "r" || secondary == "right"
        let token: String
        let isRight: Bool
        switch code {
        case 56: token = "shift"; isRight = false
        case 60: token = "shift"; isRight = true
        case 59: token = "control"; isRight = false
        case 62: token = "control"; isRight = true
        case 58: token = "option"; isRight = false
        case 61: token = "option"; isRight = true
        case 55: token = "command"; isRight = false
        case 54: token = "command"; isRight = true
        case 57: return label == "capslock"
        case 63: return ["fn", "globe", "function"].contains(label)
        default: return false
        }
        if left && isRight || right && !isRight { return false }
        switch token {
        case "control": return label.contains("control") || label.contains("ctrl") || label == "⌃"
        case "option": return label.contains("option") || label.contains("alt") || label == "⌥"
        case "command": return label.contains("command") || label.contains("cmd") || label == "⌘"
        default: return label.contains(token) || label == "⇧"
        }
    }

    private struct ModifierGroup {
        let flag: NSEvent.ModifierFlags
        let codes: [UInt16]
        let deviceMasks: [UInt]
    }

    private static let modifierGroups = [
        ModifierGroup(flag: .shift, codes: [56, 60], deviceMasks: [0x2, 0x4]),
        ModifierGroup(flag: .control, codes: [59, 62], deviceMasks: [0x1, 0x2000]),
        ModifierGroup(flag: .option, codes: [58, 61], deviceMasks: [0x20, 0x40]),
        ModifierGroup(flag: .command, codes: [55, 54], deviceMasks: [0x8, 0x10]),
        ModifierGroup(flag: .capsLock, codes: [57], deviceMasks: [0]),
        ModifierGroup(flag: .function, codes: [63], deviceMasks: [0]),
    ]

    // Apple virtual keycodes describe the emitted HID usages, not the Moonlander's
    // physical positions. These labels intentionally follow the bundled US layout;
    // charactersIgnoringModifiers would break Command shortcuts and dead keys.
    private static let printable: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[",
        34: "i", 35: "p", 37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 50: "`",
    ]

    private static let shifted = [
        "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*",
        "9": "(", "0": ")", "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|",
        ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?", "`": "~",
    ]

    private static let keypad: [UInt16: String] = [
        65: ".", 67: "*", 69: "+", 75: "/", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
    ]

    private static let special: [UInt16: String] = [
        36: "enter", 48: "tab", 49: "space", 51: "backspace", 53: "escape", 71: "clear", 76: "enter",
        115: "home", 116: "pageup", 117: "delete", 119: "end", 121: "pagedown",
        123: "left", 124: "right", 125: "down", 126: "up",
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6", 98: "f7", 100: "f8",
        101: "f9", 109: "f10", 103: "f11", 111: "f12", 105: "f13", 107: "f14", 113: "f15",
        106: "f16", 64: "f17", 79: "f18", 80: "f19", 90: "f20",
    ]
}

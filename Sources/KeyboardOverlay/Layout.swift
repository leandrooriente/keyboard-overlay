import Foundation

struct KeyLegend: Codable, Equatable {
    let label: String
    var kind: String = "standard"
    var secondary: String?
    var symbol: String?
    var shifted: String?
    var holdLayer: Int?
    var tapLayer: Int?
}

struct KeyboardLayer: Codable, Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let keys: [String: KeyLegend]
}

struct KeyboardLayout: Codable {
    let name: String
    let keyboard: String
    let layers: [KeyboardLayer]

    func legend(for key: String, layer: Int) -> KeyLegend {
        layers.first(where: { $0.id == layer })?.keys[key]
            ?? layers.first(where: { $0.id == 0 })?.keys[key]
            ?? KeyLegend(label: "", kind: "blank")
    }

    func isInherited(_ key: String, layer: Int) -> Bool {
        layer != 0 && layers.first(where: { $0.id == layer })?.keys[key] == nil
    }

    func validate() throws {
        guard layers.map(\.id) == [0, 1, 2] else {
            throw LayoutError.invalid("The layout needs layers 0, 1, and 2 in that order.")
        }
        let physicalKeys = Set(KeyGeometry.all.map(\.id))
        guard Set(layers[0].keys.keys) == physicalKeys else {
            throw LayoutError.invalid("The base layer must define all 72 Moonlander keys.")
        }
        for layer in layers {
            guard Set(layer.keys.keys).isSubset(of: physicalKeys) else {
                throw LayoutError.invalid("Layer \(layer.id) contains an unknown physical key.")
            }
            for legend in layer.keys.values {
                for target in [legend.holdLayer, legend.tapLayer].compactMap({ $0 }) {
                    if !layers.contains(where: { $0.id == target }) {
                        throw LayoutError.invalid("A key references a layer that does not exist.")
                    }
                }
            }
        }
    }

    /// A user-owned file takes precedence, so layout updates don't require rebuilding the app.
    static func load(overrideURL: URL? = nil) throws -> KeyboardLayout {
        let custom = overrideURL ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/keyboard-overlay/layout.json")
        let url: URL
        if FileManager.default.fileExists(atPath: custom.path) {
            url = custom
        } else if let bundled = resourceBundle.url(forResource: "moonlander", withExtension: "json") {
            url = bundled
        } else {
            throw LayoutError.invalid("The bundled keyboard layout could not be found.")
        }
        let layout = try JSONDecoder().decode(KeyboardLayout.self, from: Data(contentsOf: url))
        try layout.validate()
        return layout
    }

    private static var resourceBundle: Bundle {
        // SwiftPM's generated accessor expects a sibling of Bundle.main. Packaged macOS
        // apps instead keep resources in Contents/Resources, independent of the build tree.
        let packaged = Bundle.main.resourceURL?
            .appendingPathComponent("KeyboardOverlay_KeyboardOverlay.bundle")
        return packaged.flatMap(Bundle.init(url:)) ?? Bundle.module
    }
}

enum LayoutError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

enum OverlayRoute: Equatable {
    case show(Int?)
    case hide

    init?(url: URL) {
        guard url.scheme == "keyboard-overlay" else { return nil }
        if url.host == "hide" { self = .hide; return }
        guard url.host == "show" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let value = components?.queryItems?.first(where: { $0.name == "layer" })?.value {
            guard let layer = Int(value), (0...2).contains(layer) else { return nil }
            self = .show(layer)
        } else {
            self = .show(nil)
        }
    }
}

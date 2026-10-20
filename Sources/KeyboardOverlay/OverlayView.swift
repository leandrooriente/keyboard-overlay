import SwiftUI

@MainActor final class OverlayState: ObservableObject {
    @Published var layout: KeyboardLayout
    @Published var selectedLayer: Int {
        didSet {
            if persistsSelection { UserDefaults.standard.set(selectedLayer, forKey: "selectedLayer") }
        }
    }
    private let persistsSelection: Bool
    @Published var hoveredKey: String?
    @Published var loadError: String?
    var dismiss: () -> Void = {}

    init(layout: KeyboardLayout, persistsSelection: Bool = true) {
        self.layout = layout
        self.persistsSelection = persistsSelection
        selectedLayer = min(2, max(0, UserDefaults.standard.integer(forKey: "selectedLayer")))
    }

    func select(_ layer: Int) {
        selectedLayer = (layer + 3) % 3
        hoveredKey = nil
    }

    func reload() {
        do { layout = try KeyboardLayout.load(); loadError = nil }
        catch { loadError = error.localizedDescription }
    }
}

struct OverlayView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.border.opacity(0.65)).frame(height: 1)
            VStack(spacing: 0) {
                layerPicker.padding(.top, 22)
                GeometryReader { proxy in
                    let scale = min(proxy.size.width / KeyGeometry.boardWidth,
                                    proxy.size.height / KeyGeometry.boardHeight)
                    keyboard
                        .frame(width: KeyGeometry.boardWidth, height: KeyGeometry.boardHeight)
                        .scaleEffect(scale, anchor: .center)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .padding(.top, 16)
                .padding(.bottom, 10)
                footer.padding(.bottom, 20)
            }
            .padding(.horizontal, 30)
        }
        .foregroundStyle(Palette.text)
        .background(Palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.10)))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "keyboard")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(Palette.orange)
                .frame(width: 46, height: 46)
                .background(Palette.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(state.layout.keyboard.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.0).foregroundStyle(Palette.muted)
                Text(state.layout.name).font(.system(size: 21, weight: .medium))
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Palette.green).frame(width: 5, height: 5)
                Text("72 keys").font(.system(size: 11, weight: .medium))
                Text("/").foregroundStyle(Palette.border)
                Text("3 layers").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Palette.muted)
            .padding(.trailing, 18)
            Button(action: state.dismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted).frame(width: 30, height: 30)
                    .background(.white.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close overlay (Escape)")
            .accessibilityLabel("Close overlay")
        }
        .padding(.horizontal, 28).padding(.vertical, 21)
    }

    private var layerPicker: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(state.layout.layers) { layer in
                    let active = state.selectedLayer == layer.id
                    Button { state.select(layer.id) } label: {
                        HStack(spacing: 10) {
                            Text(layer.name).font(.system(size: 12, weight: .semibold))
                            Text(String(layer.id)).font(.system(size: 10, weight: .medium, design: .monospaced))
                                .frame(width: 19, height: 19)
                                .background(active ? Palette.orange.opacity(0.18) : .white.opacity(0.045),
                                            in: RoundedRectangle(cornerRadius: 4))
                        }
                        .foregroundStyle(active ? Palette.orange : Palette.muted)
                        .padding(.horizontal, 14).frame(height: 37)
                        .background(active ? Palette.orange.opacity(0.075) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(active ? Palette.orange.opacity(0.22) : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(layer.name), layer \(layer.id)")
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .help("Show \(layer.name)")
                }
            }
            .padding(4)
            .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
            Spacer()
            Text(state.layout.layers[state.selectedLayer].subtitle)
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }

    private var keyboard: some View {
        ZStack(alignment: .topLeading) {
            centerLabel
                .frame(width: 240, height: 110)
                .position(x: KeyGeometry.boardWidth / 2, y: 134)
            ForEach(KeyGeometry.all) { key in
                let legend = state.layout.legend(for: key.id, layer: state.selectedLayer)
                let inherited = state.layout.isInherited(key.id, layer: state.selectedLayer)
                Keycap(legend: legend, inherited: inherited,
                       hovered: state.hoveredKey == key.id,
                       width: key.width, height: key.height)
                    .rotationEffect(.degrees(key.rotation))
                    .position(x: key.x, y: key.y)
                    .onHover { over in
                        if over { state.hoveredKey = key.id }
                        else if state.hoveredKey == key.id { state.hoveredKey = nil }
                    }
                    .help(keyDescription(key.id))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(keyDescription(key.id))
            }
        }
    }

    private var centerLabel: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.system(size: 27, weight: .ultraLight))
                .foregroundStyle(Palette.orange.opacity(0.65))
            Text("MOONLANDER").font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(3.0).foregroundStyle(Palette.muted.opacity(0.65))
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Capsule().fill(index == state.selectedLayer ? Palette.orange : Palette.border)
                        .frame(width: index == state.selectedLayer ? 18 : 5, height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var footer: some View {
        HStack(spacing: 20) {
            HStack(spacing: 15) {
                legendDot("Modifier", Palette.green)
                legendDot("Layer / media", Palette.blue)
                legendDot("Macro", Palette.orange)
                HStack(spacing: 5) {
                    Image(systemName: "shift").font(.system(size: 10))
                    Text("Shift")
                }.foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 6)
            if let error = state.loadError {
                Text("Layout reload failed: \(error)").foregroundStyle(Palette.orange)
                    .lineLimit(2).help(error)
            } else if let key = state.hoveredKey {
                Text(keyDescription(key)).foregroundStyle(Palette.text.opacity(0.8)).lineLimit(1)
            } else {
                HStack(spacing: 14) {
                    Text("Click a tab to change layers").foregroundStyle(Palette.muted)
                    hint("esc", "close")
                }
            }
        }
        .font(.system(size: 10))
        .frame(height: 20)
    }

    private func legendDot(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.8)).frame(width: 5, height: 5)
            Text(title).foregroundStyle(Palette.muted)
        }
    }

    private func hint(_ keys: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text(keys).font(.system(size: 9, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 3))
            Text(title)
        }.foregroundStyle(Palette.muted)
    }

    private func keyDescription(_ id: String) -> String {
        let legend = state.layout.legend(for: id, layer: state.selectedLayer)
        var description = legend.label.isEmpty ? "Unassigned" : legend.label.replacingOccurrences(of: "\n", with: " ")
        if let shifted = legend.shifted { description += " · Shift: \(shifted)" }
        if let layer = legend.holdLayer { description += " · hold for layer \(layer)" }
        else if let layer = legend.tapLayer { description += " · tap for layer \(layer)" }
        else if let secondary = legend.secondary { description += " · \(secondary)" }
        if state.layout.isInherited(id, layer: state.selectedLayer) { description += " · from Base" }
        return description
    }
}

private struct Keycap: View {
    let legend: KeyLegend
    let inherited: Bool
    let hovered: Bool
    let width: Double
    let height: Double

    private var accent: Color { Palette.accent(legend.kind) }
    private var isPlain: Bool { ["standard", "blank", "disabled"].contains(legend.kind) }
    private var muted: Bool { inherited || legend.kind == "source" }

    var body: some View {
        VStack(spacing: 5) {
            if let symbol = legend.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .regular))
            } else {
                Text(legend.label)
                    .font(.system(size: legend.label.count > 4 ? 11 : 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.7)
            }
            if let layer = legend.holdLayer ?? legend.tapLayer {
                HStack(spacing: 3) {
                    Image(systemName: "square.2.layers.3d")
                    Text("\(layer) \(legend.tapLayer == nil ? "hold" : "tap")")
                }
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(muted ? Palette.muted.opacity(0.35) : Palette.blue)
            } else if let secondary = legend.secondary {
                Text(secondary).font(.system(size: 8, weight: .medium))
            }
        }
        .foregroundStyle(muted ? Palette.muted.opacity(0.35) : accent)
        .padding(.horizontal, 4)
        .frame(width: width, height: height)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(muted ? Palette.background : (isPlain ? Palette.surface : accent.opacity(0.10)))
                .shadow(color: .black.opacity(muted ? 0 : 0.18), radius: 1, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(muted ? Palette.border.opacity(0.4) :
                                (hovered ? accent.opacity(0.85) : (isPlain ? Palette.border : accent.opacity(0.35))),
                              lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
            if !muted && !isPlain {
                RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.45))
                    .frame(width: 14, height: 2).padding(.bottom, 5)
            }
        }
        .overlay(alignment: .topLeading) {
            if let shifted = legend.shifted {
                Text(shifted)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted.opacity(muted ? 0.35 : 0.9))
                    .padding(.top, 6)
                    .padding(.leading, 8)
            }
        }
    }
}

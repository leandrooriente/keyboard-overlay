import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var state: OverlayState?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private var previousApplication: NSRunningApplication?
    private let args = CommandLine.arguments
    private var pendingRoute: OverlayRoute?
    private var finishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let layout = try KeyboardLayout.load()
            let model = OverlayState(layout: layout, persistsSelection: !args.contains("--render-preview"))
            model.dismiss = { [weak self] in self?.hide() }
            state = model
            if let previewIndex = args.firstIndex(of: "--render-preview"), args.indices.contains(previewIndex + 1) {
                if let layer = argumentLayer { model.select(layer) }
                renderPreview(to: args[previewIndex + 1], model: model)
                NSApp.terminate(nil)
                return
            }
            configurePanel(model: model)
            finishedLaunching = true
            if let route = pendingRoute { handle(route) }
            else { show(layer: argumentLayer) }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not load keyboard layout"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let route = OverlayRoute(url: url) else { continue }
            if finishedLaunching { handle(route) }
            else { pendingRoute = route }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show(layer: nil)
        return false
    }

    private var argumentLayer: Int? {
        guard let index = args.firstIndex(of: "--layer"), args.indices.contains(index + 1),
              let layer = Int(args[index + 1]), (0...2).contains(layer) else { return nil }
        return layer
    }

    private func handle(_ route: OverlayRoute) {
        switch route {
        case .show(let layer): show(layer: layer)
        case .hide: hide()
        }
    }

    private func configurePanel(model: OverlayState) {
        let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 1310, height: 750),
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.title = "Keyboard Overlay"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: OverlayView(state: model))
        self.panel = panel
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            if event.type != .keyDown {
                if event.window !== self.panel { self.hide() }
                return event
            }
            if self.handleKey(event) { return nil }
            return event
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didResignKey),
                                               name: NSWindow.didResignKeyNotification, object: panel)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let state else { return false }
        if event.keyCode == 53 { hide(); return true }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            if event.charactersIgnoringModifiers == "q" { NSApp.terminate(nil); return true }
            if event.charactersIgnoringModifiers == "r" { state.reload(); return true }
            return false
        }
        return false
    }

    private func show(layer: Int?) {
        guard let panel, let state else { return }
        state.reload()
        if let layer { state.select(layer) }
        state.hoveredKey = nil
        if !panel.isVisible {
            previousApplication = NSWorkspace.shared.frontmostApplication
            let pointer = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
            if let screen {
                let available = screen.visibleFrame
                let scale = min(1, min((available.width - 56) / 1310, (available.height - 56) / 750))
                let size = NSSize(width: 1310 * scale, height: 750 * scale)
                panel.setFrame(NSRect(x: available.midX - size.width / 2,
                                      y: available.midY - size.height / 2,
                                      width: size.width, height: size.height), display: false)
            }
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        // Nonactivating panels normally preserve app focus; restore it if macOS activated us.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            previousApplication?.activate(options: [])
        }
        previousApplication = nil
    }

    @objc private func didResignKey() {
        hide()
    }

    private func renderPreview(to path: String, model: OverlayState) {
        let view = OverlayView(state: model).frame(width: 1310, height: 750)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else {
            fputs("Unable to render preview.\n", stderr)
            exit(1)
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        do {
            guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
            try png.write(to: URL(fileURLWithPath: path))
        } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    }
}

@main enum KeyboardOverlayApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

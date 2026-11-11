import AppKit
import SwiftUI
import ConvoyDomain

/// Ícono de la barra de menú: clic abre la ventana; clic derecho (o ⌃clic) abre el menú.
final class StatusButtonView: NSView {
    var onClick: () -> Void = {}
    var onRightClick: () -> Void = {}
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { onRightClick() } else { onClick() }
    }
    override func rightMouseDown(with event: NSEvent) { onRightClick() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var settings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.setAccessibilityLabel("Convoy")
            let overlay = StatusButtonView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.onClick = { [weak self] in self?.toggleWindow() }
            overlay.onRightClick = { [weak self] in self?.showMenu() }
            button.addSubview(overlay)
        }
        HotKeyCenter.shared.onPress = { [weak self] in self?.toggleWindow() }
        HotKeyCenter.shared.applyPreferences()
        if !Prefs.onboardingDone { Prefs.onboardingDone = true; showWindow() }
    }

    // MARK: Ventana

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 852, height: 712), styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.contentViewController = NSHostingController(rootView: MainView(model: model) { [weak self] in self?.window?.close() })
        w.setContentSize(NSSize(width: 852, height: 712))
        w.center()
        return w
    }

    func showWindow() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        model.focusTick += 1
    }

    private func toggleWindow() {
        if let w = window, w.isVisible, w.isKeyWindow { w.close() } else { showWindow() }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Nuevo proyecto"), action: #selector(openFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("Ajustes…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Salir de Convoy"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openFromMenu() { showWindow() }

    @objc private func openSettings() {
        if settings == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = L("Ajustes de Convoy")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settings = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    // MARK: Entradas externas

    /// `convoy://new?path=/ruta` (lo lanza la Acción rápida del Finder) y archivos `.convoy` (doble clic).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "convoy", url.host == "new" {
                let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "path" }?.value
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.model.prepare(destination: path.map { URL(fileURLWithPath: $0, isDirectory: true) })
                    self?.showWindow()
                }
            } else if url.isFileURL, url.pathExtension == "convoy" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.model.importTemplate(from: url)
                    self?.model.tab = .templates
                    self?.showWindow()
                }
            }
        }
    }

    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"), let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }
        let fallback = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Convoy")
        fallback?.isTemplate = true
        return fallback
    }
}

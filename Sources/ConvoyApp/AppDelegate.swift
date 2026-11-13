import AppKit
import SwiftUI
import ConvoyDomain
import ConvoyLicensing

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
    let trial = TrialController.live()
    let model: AppModel
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var settings: NSWindow?
    private var activation: NSWindow?

    override init() {
        model = AppModel(trial: trial)
        super.init()
        model.onTrialExpired = { [weak self] in self?.showActivation() }
    }

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
        trial.refresh()
        if trial.isExpired { showActivation(); return }
        if !Prefs.onboardingDone { Prefs.onboardingDone = true; showWindow() }
        if !trial.manager.welcomeSeen {
            trial.manager.markWelcomeSeen()
            _ = trial.manager.takeDailyReminder()   // el primer día ya vio el aviso de bienvenida
            showWelcome()
        } else if let days = trial.manager.takeDailyReminder() {
            showReminder(daysLeft: days)
        }
    }

    // MARK: Prueba y licencia

    private func runNotice(title: String, body: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: L("Entendido"))
        alert.addButton(withTitle: L("Obtener premium"))
        if alert.runModal() == .alertSecondButtonReturn { trial.openPurchase() }
    }

    /// Primer arranque: se muestra una sola vez.
    private func showWelcome() { runNotice(title: TrialTexts.welcomeTitle, body: TrialTexts.welcomeBody(endDate: trial.endDateText)) }

    /// Últimos 14 días: como máximo una vez por día.
    private func showReminder(daysLeft: Int) {
        runNotice(title: daysLeft == 1 ? L("Último día de prueba") : L("Quedan %d días de prueba", daysLeft), body: TrialTexts.reminderBody(daysLeft: daysLeft, endDate: trial.endDateText))
    }

    /// Ventana de activación: con la prueba vencida no se cierra (solo se activa o se sale).
    func showActivation() {
        trial.refresh()
        let expired = trial.isExpired
        activation?.close()
        let w = NSWindow(contentRect: .zero, styleMask: expired ? [.titled] : [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("Convoy premium")
        w.isReleasedWhenClosed = false
        w.contentViewController = NSHostingController(rootView: ActivationView(
            trial: trial, expired: expired,
            close: { [weak self] in self?.activation?.close() }, quit: { NSApp.terminate(nil) }))
        w.center()
        activation = w
        window?.close()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
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
        trial.refresh()
        if trial.isExpired { showActivation(); return }
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
        trial.refresh()
        menu.addItem(withTitle: TrialTexts.menuLine(trial.state, buyer: trial.buyer), action: nil, keyEquivalent: "")
        if !trial.isLicensed { menu.addItem(withTitle: L("Obtener premium…"), action: #selector(buyPremium), keyEquivalent: "").target = self }
        menu.addItem(withTitle: trial.isLicensed ? L("Licencia…") : L("Introducir clave…"), action: #selector(enterKey), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Salir de Convoy"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openFromMenu() { showWindow() }
    @objc private func buyPremium() { trial.openPurchase() }
    @objc private func enterKey() { if trial.isLicensed { openSettings() } else { showActivation() } }

    @objc private func openSettings() {
        if settings == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(trial: trial)))
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
    /// Con la prueba vencida no se opera: se muestra la ventana de activación.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "convoy", url.host == "new" {
                let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "path" }?.value
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    self.trial.refresh()
                    if self.trial.isExpired { self.showActivation(); return }
                    self.model.prepare(requestedPath: path)
                    self.showWindow()
                }
            } else if url.isFileURL, url.pathExtension == "convoy" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    self.trial.refresh()
                    if self.trial.isExpired { self.showActivation(); return }
                    self.confirmImport(url)
                }
            }
        }
    }

    /// Un `.convoy` abierto desde fuera no se importa solo: se pregunta primero.
    private func confirmImport(_ url: URL) {
        switch model.previewImport(from: url) {
        case .failure:
            model.importTemplate(from: url)   // muestra el motivo del rechazo
        case .success(let t):
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("¿Importar la plantilla «%@» con %d carpetas?", t.name, t.folderCount)
            alert.informativeText = L("Importa solo plantillas de personas de confianza. Solo se crearán carpetas vacías cuando la uses.")
            alert.addButton(withTitle: L("Importar"))
            alert.addButton(withTitle: L("Cancelar"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            model.importTemplate(from: url)
        }
        model.tab = .templates
        showWindow()
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

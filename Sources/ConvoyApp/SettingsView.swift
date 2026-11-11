import SwiftUI
import ServiceManagement
import ConvoyLicensing

@MainActor
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) -> String? {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; return nil }
        catch { return error.localizedDescription }
    }
}

struct SettingsView: View {
    var trial: TrialController
    @State private var showKeyField = false
    @State private var key = ""
    @State private var keyError: String?
    @AppStorage(Prefs.stripAccentsKey) private var stripAccents = false
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var label = Prefs.hotKeyLabel
    @State private var hotKeyMessage: String?
    @State private var actionInstalled = QuickAction.isInstalled
    @State private var actionMessage: String?

    var body: some View {
        Form {
            Section(L("Nombres")) {
                Toggle(L("Quitar tildes de los nombres"), isOn: $stripAccents)
                Text(L("«Expansión Perú» pasa a «Expansion Peru». La ñ se conserva. Útil si compartes con sistemas antiguos."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Abrir Convoy")) {
                LabeledContent(L("Atajo global")) {
                    HotKeyRecorder(label: $label) { code, mods in
                        Prefs.hotKey = (code, mods)
                        let ok = HotKeyCenter.shared.applyPreferences()
                        label = Prefs.hotKeyLabel
                        hotKeyMessage = ok ? nil : L("Ese atajo ya lo usa otro programa. Prueba otro.")
                    }.frame(width: 150, height: 24)
                }
                HStack {
                    Button(L("Restablecer")) { Prefs.hotKey = Prefs.defaultHotKey; HotKeyCenter.shared.applyPreferences(); label = Prefs.hotKeyLabel; hotKeyMessage = nil }
                    Button(L("Quitar atajo")) { Prefs.hotKey = nil; HotKeyCenter.shared.applyPreferences(); label = Prefs.hotKeyLabel; hotKeyMessage = nil }
                }
                if let hotKeyMessage { Text(hotKeyMessage).font(.caption).foregroundStyle(.red) }
                Toggle(L("Abrir Convoy al iniciar sesión"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        loginError = LoginItem.set(on)
                        if loginError != nil { launchAtLogin = LoginItem.isEnabled }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }
            Section(L("Menú del Finder")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Nuevo proyecto con Convoy"))
                        Text(L("Clic derecho en una carpeta → Acciones rápidas → Nuevo proyecto con Convoy."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(actionInstalled ? L("Quitar acción") : L("Instalar")) {
                        actionMessage = actionInstalled ? QuickAction.remove() : QuickAction.install()
                        actionInstalled = QuickAction.isInstalled
                    }
                }
                if actionInstalled {
                    Text(L("Si no aparece, actívala en Ajustes del Sistema → Teclado → Atajos de teclado → Servicios → Archivos y carpetas."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let actionMessage { Text(actionMessage).font(.caption).foregroundStyle(.red) }
            }
            Section(L("Licencia")) {
                if trial.isLicensed {
                    Text(L("Premium activado · %@", trial.buyer ?? ""))
                    Button(L("Quitar licencia")) { trial.removeLicense() }
                } else {
                    Text(trial.isExpired ? L("Periodo de prueba terminado") : (TrialTexts.banner(trial.state) ?? ""))
                    Text(trial.trialEndText).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("Obtener premium")) { trial.openPurchase() }
                        Button(L("Introducir clave…")) { showKeyField.toggle() }
                    }
                    if showKeyField {
                        TextField(L("Tengo una clave"), text: $key).font(.system(.body, design: .monospaced))
                            .onSubmit(activate)
                        Button(L("Activar"), action: activate).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let keyError { Text(keyError).font(.caption).foregroundStyle(.red) }
                }
            }
            Section {
                Text(L("Convoy no usa internet (solo abre la página de compra en tu navegador si lo pides) ni guarda datos de tus proyectos. Solo crea carpetas vacías.")).font(.caption).foregroundStyle(.secondary)
                Text(L("Versión %@", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 660)
    }

    private func activate() {
        if let e = trial.activate(key) { keyError = e } else { key = ""; keyError = nil; showKeyField = false }
    }
}

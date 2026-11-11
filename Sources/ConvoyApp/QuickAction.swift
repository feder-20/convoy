import AppKit
import ConvoyDomain

/// «Nuevo proyecto con Convoy» en el menú de Acciones rápidas del Finder (sobre una carpeta o el fondo de una ventana).
/// Es un flujo de Automator que abre `convoy://new?path=…`; se instala en ~/Library/Services.
enum QuickAction {
    static let name = "Nuevo proyecto con Convoy"
    static var installedURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services/\(name).workflow", isDirectory: true)
    }
    static var isInstalled: Bool { FileManager.default.fileExists(atPath: installedURL.path) }
    static var bundledURL: URL? { Bundle.main.url(forResource: name, withExtension: "workflow") }

    /// Devuelve un mensaje de error o nil si todo salió bien. El texto del menú queda en el idioma del sistema.
    static func install() -> String? {
        guard let src = bundledURL else { return tr("Esta copia de Convoy no incluye la Acción rápida.") }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: installedURL.path) { try fm.removeItem(at: installedURL) }
            try fm.copyItem(at: src, to: installedURL)
            try localizeMenuItem()
            refreshServices()
            return nil
        } catch { return error.localizedDescription }
    }

    static func remove() -> String? {
        do { try FileManager.default.removeItem(at: installedURL); refreshServices(); return nil }
        catch { return error.localizedDescription }
    }

    private static func localizeMenuItem() throws {
        let url = installedURL.appendingPathComponent("Contents/Info.plist")
        var plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] ?? [:]
        guard var services = plist["NSServices"] as? [[String: Any]], !services.isEmpty else { return }
        services[0]["NSMenuItem"] = ["default": L("Nuevo proyecto con Convoy")]
        plist["NSServices"] = services
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)
    }

    private static func refreshServices() {
        let pbs = Process()
        pbs.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
        pbs.arguments = ["-update"]
        try? pbs.run()
    }
}

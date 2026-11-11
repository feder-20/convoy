import Foundation
import ConvoyDomain

/// Valida la carpeta de destino que pide un enlace externo (`convoy://new?path=`). La parte de rutas es pura;
/// la comprobación de disco (existe, es carpeta, se puede escribir) se inyecta.
public struct DestinationValidator: Sendable {
    public enum Rejection: Error, Equatable, Sendable {
        case notAbsolute, notStandardized, missing, notDirectory, notWritable, forbidden, hidden
        public var message: String {
            switch self {
            case .notAbsolute, .notStandardized: return tr("La ruta del enlace no es una ruta absoluta y limpia.")
            case .missing: return tr("La carpeta del enlace no existe.")
            case .notDirectory: return tr("La ruta del enlace no es una carpeta.")
            case .notWritable: return tr("No se puede escribir en la carpeta del enlace.")
            case .forbidden: return tr("La carpeta del enlace es una carpeta del sistema o protegida.")
            case .hidden: return tr("La carpeta del enlace está oculta.")
            }
        }
    }

    public struct Probe: Sendable {
        public var isDirectory: @Sendable (String) -> Bool?   // nil = no existe
        public var isWritable: @Sendable (String) -> Bool
        public var resolve: @Sendable (String) -> String
        public init(isDirectory: @escaping @Sendable (String) -> Bool?, isWritable: @escaping @Sendable (String) -> Bool,
                    resolve: @escaping @Sendable (String) -> String) {
            self.isDirectory = isDirectory; self.isWritable = isWritable; self.resolve = resolve
        }
        public static let live = Probe(
            isDirectory: { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: $0, isDirectory: &d) ? d.boolValue : nil },
            isWritable: { FileManager.default.isWritableFile(atPath: $0) },
            resolve: { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL.path })
    }

    static let forbiddenPrefixes = ["/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/etc", "/private", "/dev", "/var", "/cores", "/tmp"]
    static let forbiddenExact = ["/", "/Users", "/Volumes"]

    private let home: String
    private let probe: Probe
    public init(home: String = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path, probe: Probe = .live) {
        self.home = home
        self.probe = probe
    }

    /// Parte pura: ruta absoluta estandarizada, sin carpetas ocultas y fuera de las zonas protegidas.
    public func checkPath(_ raw: String) -> Rejection? {
        guard raw.hasPrefix("/"), !raw.contains("\0") else { return .notAbsolute }
        var path = raw
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        // Estandarizada: sin componentes vacíos, «.» ni «..» (comprobación léxica; no se usa standardizedFileURL
        // porque en macOS reescribe «/private/…»).
        let components = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        if path != "/", components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) { return .notStandardized }
        if let r = zoneRejection(path) { return r }
        // Un enlace simbólico no puede llevar a una zona protegida.
        let resolved = probe.resolve(path)
        if resolved != path, let r = zoneRejection(resolved) { return r }
        return nil
    }

    private func zoneRejection(_ path: String) -> Rejection? {
        if Self.forbiddenExact.contains(path) { return .forbidden }
        for p in Self.forbiddenPrefixes where path == p || path.hasPrefix(p + "/") { return .forbidden }
        let library = home + "/Library"
        if path == library || path.hasPrefix(library + "/") { return .forbidden }
        if path == home + "/.ssh" || path.hasPrefix(home + "/.ssh/") { return .forbidden }
        if path.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { return .hidden }
        return nil
    }

    /// Devuelve la carpeta si el enlace es aceptable, o el motivo del rechazo.
    public func validate(_ raw: String) -> Result<URL, Rejection> {
        if let r = checkPath(raw) { return .failure(r) }
        var path = raw
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        switch probe.isDirectory(path) {
        case nil: return .failure(.missing)
        case false?: return .failure(.notDirectory)
        case true?: break
        }
        guard probe.isWritable(path) else { return .failure(.notWritable) }
        return .success(URL(fileURLWithPath: path, isDirectory: true))
    }
}

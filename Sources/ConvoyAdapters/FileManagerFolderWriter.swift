import Foundation
import ConvoyDomain
import ConvoyPorts

/// Crea el árbol completo en una carpeta temporal del mismo volumen y lo mueve de una vez al destino.
/// Nunca toca nada fuera de esa carpeta temporal ni sobrescribe (convoy.md §8.3).
public struct FileManagerFolderWriter: FolderWriter {
    private let afterEachFolder: @Sendable (Int) throws -> Void

    /// `afterEachFolder` recibe el índice de la carpeta recién creada; las pruebas lo usan para simular un fallo.
    public init(afterEachFolder: @escaping @Sendable (Int) throws -> Void = { _ in }) {
        self.afterEachFolder = afterEachFolder
    }

    /// Un segmento válido es un solo nombre: sin «/», sin NUL, ni «.» ni «..», ni vacío.
    static func isSafeSegment(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.unicodeScalars.contains { $0 == "/" || $0 == "\0" }
    }

    public func exists(_ name: String, in parent: URL) throws -> Bool {
        guard Self.isSafeSegment(name) else { throw ConvoyError.creationFailed(parent.lastPathComponent) }
        return FileManager.default.fileExists(atPath: parent.appendingPathComponent(name).path)
    }

    public func create(_ plan: CreationPlan, in parent: URL) async throws -> URL {
        let fm = FileManager.default
        let failure = ConvoyError.creationFailed(parent.lastPathComponent)
        // El plan puede venir de cualquier parte: se comprueba antes de tocar el disco.
        guard Self.isSafeSegment(plan.rootName), plan.folders.allSatisfy({ $0.relativePath.allSatisfy(Self.isSafeSegment) }) else { throw failure }
        let final = parent.appendingPathComponent(plan.rootName, isDirectory: true)
        let parentPath = parent.standardizedFileURL.path
        guard final.standardizedFileURL.deletingLastPathComponent().path == parentPath,
              final.standardizedFileURL.lastPathComponent == plan.rootName else { throw failure }
        if fm.fileExists(atPath: final.path) { throw ConvoyError.alreadyExists(plan.rootName) }

        let temp: URL
        do { temp = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: parent, create: true) }
        catch { throw map(error, parent) }
        // Pase lo que pase, esa carpeta temporal es de Convoy y se retira al terminar.
        defer { try? fm.removeItem(at: temp) }

        do {
            let root = temp.appendingPathComponent(plan.rootName, isDirectory: true)
            let rootPrefix = root.standardizedFileURL.path + "/"
            guard root.standardizedFileURL.deletingLastPathComponent().path == temp.standardizedFileURL.path else { throw failure }
            try fm.createDirectory(at: root, withIntermediateDirectories: false)
            for (index, folder) in plan.folders.enumerated() {
                let url = folder.relativePath.reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
                guard url.standardizedFileURL.path.hasPrefix(rootPrefix) else { throw failure }
                try fm.createDirectory(at: url, withIntermediateDirectories: false)
                try afterEachFolder(index)
            }
            try fm.moveItem(at: root, to: final)   // mismo volumen: es un renombrado atómico
        } catch let e as ConvoyError {
            throw e
        } catch {
            throw map(error, parent)
        }
        return final
    }

    private func map(_ error: Error, _ parent: URL) -> ConvoyError {
        let ns = error as NSError
        let denied = (ns.domain == NSCocoaErrorDomain && [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(ns.code))
            || (ns.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(ns.code))
            || ((ns.userInfo[NSUnderlyingErrorKey] as? NSError).map { $0.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains($0.code) } ?? false)
        return denied ? .noPermission(parent) : .creationFailed(parent.lastPathComponent)
    }
}

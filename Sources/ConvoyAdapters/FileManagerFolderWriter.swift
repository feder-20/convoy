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

    public func exists(_ name: String, in parent: URL) throws -> Bool {
        FileManager.default.fileExists(atPath: parent.appendingPathComponent(name).path)
    }

    public func create(_ plan: CreationPlan, in parent: URL) async throws -> URL {
        let fm = FileManager.default
        let final = parent.appendingPathComponent(plan.rootName, isDirectory: true)
        if fm.fileExists(atPath: final.path) { throw ConvoyError.alreadyExists(plan.rootName) }

        let temp: URL
        do { temp = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: parent, create: true) }
        catch { throw map(error, parent) }
        // Pase lo que pase, esa carpeta temporal es de Convoy y se retira al terminar.
        defer { try? fm.removeItem(at: temp) }

        do {
            let root = temp.appendingPathComponent(plan.rootName, isDirectory: true)
            try fm.createDirectory(at: root, withIntermediateDirectories: false)
            for (index, folder) in plan.folders.enumerated() {
                let url = folder.relativePath.reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
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

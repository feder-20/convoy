import Foundation

/// Edición pura de plantillas (sin disco): la usan las pantallas y se prueba sin interfaz.
public extension Template {
    mutating func addFolder(named name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        folders.append(FolderNode(name: clean))
    }

    mutating func addSubfolder(named name: String, to parent: UUID) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let i = folders.firstIndex(where: { $0.id == parent }) else { return }
        folders[i].children.append(FolderNode(name: clean))
    }

    mutating func rename(folder id: UUID, to name: String) {
        if let i = folders.firstIndex(where: { $0.id == id }) { folders[i].name = name; return }
        for i in folders.indices {
            if let j = folders[i].children.firstIndex(where: { $0.id == id }) { folders[i].children[j].name = name; return }
        }
    }

    mutating func remove(folder id: UUID) {
        folders.removeAll { $0.id == id }
        for i in folders.indices { folders[i].children.removeAll { $0.id == id } }
    }

    /// Sube (-1) o baja (+1) una carpeta dentro de su nivel.
    mutating func move(folder id: UUID, by delta: Int) {
        func shift(_ list: inout [FolderNode]) -> Bool {
            guard let i = list.firstIndex(where: { $0.id == id }) else { return false }
            let j = i + delta
            guard list.indices.contains(j) else { return true }
            list.swapAt(i, j)
            return true
        }
        if shift(&folders) { return }
        for i in folders.indices { if shift(&folders[i].children) { return } }
    }

    /// Copia con identificadores nuevos, propia (no de fábrica).
    func duplicated(named newName: String) -> Template {
        func fresh(_ n: FolderNode) -> FolderNode { FolderNode(name: n.name, children: n.children.map(fresh)) }
        return Template(name: newName, isBuiltIn: false, folders: folders.map(fresh))
    }
}

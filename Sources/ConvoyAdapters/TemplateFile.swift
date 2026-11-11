import Foundation
import ConvoyDomain

/// Formato `.convoy` (JSON): sirve para exportar, importar y compartir plantillas (convoy.md §7.2).
struct TemplateFile: Codable {
    struct Node: Codable {
        var name: String
        var children: [Node]?
    }
    static let currentVersion = 1

    var schemaVersion: Int
    var name: String
    var folders: [Node]

    init(_ t: Template) {
        schemaVersion = Self.currentVersion
        name = t.name
        folders = t.folders.map { Node(name: $0.name, children: $0.children.isEmpty ? nil : $0.children.map { Node(name: $0.name, children: nil) }) }
    }

    static func decode(_ data: Data) throws -> TemplateFile {
        let file: TemplateFile
        do { file = try JSONDecoder().decode(TemplateFile.self, from: data) }
        catch { throw ConvoyError.invalidTemplateFile(tr("No es un archivo de plantilla de Convoy.")) }
        guard file.schemaVersion >= 1 else { throw ConvoyError.invalidTemplateFile(tr("No es un archivo de plantilla de Convoy.")) }
        guard file.schemaVersion <= currentVersion else { throw ConvoyError.invalidTemplateFile(tr("Es de una versión más nueva de Convoy.")) }
        guard !file.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConvoyError.invalidTemplateFile(tr("La plantilla no tiene nombre."))
        }
        for node in file.folders {
            guard !node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConvoyError.invalidTemplateFile(tr("Hay una carpeta sin nombre."))
            }
            for child in node.children ?? [] {
                guard !child.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ConvoyError.invalidTemplateFile(tr("Hay una carpeta sin nombre."))
                }
                guard (child.children ?? []).isEmpty else {
                    throw ConvoyError.invalidTemplateFile(tr("Tiene subcarpetas de más de un nivel, que Convoy todavía no admite."))
                }
            }
        }
        return file
    }

    func template(id: UUID = UUID(), builtIn: Bool = false) -> Template {
        Template(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), isBuiltIn: builtIn,
                 folders: folders.map { FolderNode(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                    children: ($0.children ?? []).map { FolderNode(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)) }) },
                 schemaVersion: schemaVersion)
    }

    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(self)
    }
}

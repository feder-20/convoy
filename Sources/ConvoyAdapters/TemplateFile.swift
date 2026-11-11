import Foundation
import ConvoyDomain

/// Formato `.convoy` (JSON): sirve para exportar, importar y compartir plantillas (convoy.md §7.2).
struct TemplateFile: Codable {
    struct Node: Codable {
        var name: String
        var children: [Node]?
    }
    static let currentVersion = 1
    /// Límites de seguridad para archivos que llegan de fuera (doble clic, importar).
    static let maxFileBytes = 1_048_576
    static let maxFolders = 99
    static let maxFolderNameLength = 255
    static let maxTemplateNameLength = 80

    var schemaVersion: Int
    var name: String
    var folders: [Node]

    init(_ t: Template) {
        schemaVersion = Self.currentVersion
        name = t.name
        folders = t.folders.map { Node(name: $0.name, children: $0.children.isEmpty ? nil : $0.children.map { Node(name: $0.name, children: nil) }) }
    }

    /// Lee un archivo `.convoy` solo si es regular y pesa a lo sumo 1 MB (se comprueba antes de leer).
    static func readData(at url: URL) throws -> Data {
        let unreadable = ConvoyError.invalidTemplateFile(tr("No se pudo leer el archivo."))
        let path = url.resolvingSymlinksInPath().path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { throw unreadable }
        guard attrs[.type] as? FileAttributeType == .typeRegular else {
            throw ConvoyError.invalidTemplateFile(tr("No es un archivo normal."))
        }
        guard let size = (attrs[.size] as? NSNumber)?.intValue, size <= maxFileBytes else {
            throw ConvoyError.invalidTemplateFile(tr("El archivo pesa más de 1 MB."))
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { throw unreadable }
        return data
    }

    static func decode(_ data: Data) throws -> TemplateFile {
        guard data.count <= maxFileBytes else { throw ConvoyError.invalidTemplateFile(tr("El archivo pesa más de 1 MB.")) }
        let file: TemplateFile
        do { file = try JSONDecoder().decode(TemplateFile.self, from: data) }
        catch { throw ConvoyError.invalidTemplateFile(tr("No es un archivo de plantilla de Convoy.")) }
        guard file.schemaVersion >= 1 else { throw ConvoyError.invalidTemplateFile(tr("No es un archivo de plantilla de Convoy.")) }
        guard file.schemaVersion <= currentVersion else { throw ConvoyError.invalidTemplateFile(tr("Es de una versión más nueva de Convoy.")) }
        guard !file.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConvoyError.invalidTemplateFile(tr("La plantilla no tiene nombre."))
        }
        guard file.name.count <= maxTemplateNameLength else {
            throw ConvoyError.invalidTemplateFile(tr("El nombre de la plantilla supera los 80 caracteres."))
        }
        guard file.folders.count <= maxFolders else { throw ConvoyError.invalidTemplateFile(tr("Una plantilla admite hasta 99 carpetas de primer nivel.")) }
        for node in file.folders {
            guard (node.children ?? []).count <= maxFolders else {
                throw ConvoyError.invalidTemplateFile(tr("Una carpeta admite hasta 99 subcarpetas."))
            }
            guard node.name.count <= maxFolderNameLength, (node.children ?? []).allSatisfy({ $0.name.count <= maxFolderNameLength }) else {
                throw ConvoyError.invalidTemplateFile(tr("Hay un nombre de carpeta de más de 255 caracteres."))
            }
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

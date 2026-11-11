import Foundation
import ConvoyDomain

public protocol FolderWriter: Sendable {
    func exists(_ name: String, in parent: URL) throws -> Bool
    /// Crea todo el árbol o nada (atómico). Devuelve la carpeta madre creada.
    func create(_ plan: CreationPlan, in parent: URL) async throws -> URL
}

public protocol TemplateRepository: Sendable {
    /// Plantillas de fábrica primero y luego las propias.
    func all() throws -> [Template]
    func save(_ template: Template) throws
    func delete(id: UUID) throws
    func importFile(at url: URL) throws -> Template
    func export(_ template: Template, to url: URL) throws
}

public protocol LocationAccess: Sendable {
    /// Da acceso a la carpeta mientras dura `body` (marcador de seguridad cuando hay sandbox).
    func withAccess<T: Sendable>(to url: URL, _ body: () async throws -> T) async throws -> T
    func remember(_ url: URL) throws
    func recent() -> [URL]
    func defaultLocation() -> URL?
    func setDefaultLocation(_ url: URL) throws
}

public protocol FinderRevealer: Sendable {
    func reveal(_ url: URL)
}

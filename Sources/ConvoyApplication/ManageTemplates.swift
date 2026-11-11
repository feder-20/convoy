import Foundation
import ConvoyDomain
import ConvoyPorts

/// Crear, duplicar, editar, eliminar, importar y exportar plantillas. Las de fábrica no se modifican.
public struct ManageTemplates: Sendable {
    private let repository: TemplateRepository
    public init(repository: TemplateRepository) { self.repository = repository }

    public func all() throws -> [Template] { try repository.all() }

    @discardableResult
    public func createEmpty(named name: String) throws -> Template {
        let t = Template(name: try uniqueName(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? tr("Nueva plantilla") : name), folders: [])
        try repository.save(t)
        return t
    }

    @discardableResult
    public func duplicate(_ template: Template) throws -> Template {
        let copy = template.duplicated(named: try uniqueName(tr("%@ copia", template.name)))
        try repository.save(copy)
        return copy
    }

    public func update(_ template: Template) throws {
        guard !template.isBuiltIn else { throw ConvoyError.builtInTemplate }
        try repository.save(template)
    }

    public func delete(_ template: Template) throws {
        guard !template.isBuiltIn else { throw ConvoyError.builtInTemplate }
        try repository.delete(id: template.id)
    }

    /// Lee y valida un `.convoy` sin guardarlo (para pedir confirmación antes de importar).
    public func preview(fileAt url: URL) throws -> Template { try repository.importFile(at: url) }

    @discardableResult
    public func importFile(at url: URL) throws -> Template {
        var t = try repository.importFile(at: url)
        t.isBuiltIn = false
        t.name = try uniqueName(t.name)
        try repository.save(t)
        return t
    }

    public func export(_ template: Template, to url: URL) throws { try repository.export(template, to: url) }

    /// «Proyecto», «Proyecto 2», «Proyecto 3»… sin repetir nombres existentes.
    private func uniqueName(_ wanted: String) throws -> String {
        let existing = Set(try repository.all().map { $0.name.lowercased() })
        let base = wanted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.contains(base.lowercased()) { return base }
        var n = 2
        while existing.contains("\(base) \(n)".lowercased()) { n += 1 }
        return "\(base) \(n)"
    }
}

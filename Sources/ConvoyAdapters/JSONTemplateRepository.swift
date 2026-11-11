import Foundation
import ConvoyDomain
import ConvoyPorts

/// Plantillas de fábrica (del bundle) + plantillas propias (un `.convoy` por plantilla en Application Support).
public struct JSONTemplateRepository: TemplateRepository {
    /// Identificadores fijos: la selección de una plantilla de fábrica sobrevive a los reinicios.
    static let builtIns: [(file: String, id: UUID)] = [
        ("proyecto", UUID(uuidString: "C0A10001-0000-4000-8000-000000000001")!),
        ("campana", UUID(uuidString: "C0A10001-0000-4000-8000-000000000002")!),
        ("tecnologia", UUID(uuidString: "C0A10001-0000-4000-8000-000000000003")!),
    ]
    public static let builtInIDs = Set(builtIns.map(\.id))

    private let userDirectory: URL
    private let builtInDirectory: URL?

    public init(userDirectory: URL? = nil, builtInDirectory: URL? = nil) {
        self.userDirectory = userDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Convoy/templates", isDirectory: true)
        self.builtInDirectory = builtInDirectory ?? Bundle.main.resourceURL?.appendingPathComponent("BuiltInTemplates", isDirectory: true)
    }

    public func all() throws -> [Template] {
        var result: [Template] = []
        if let dir = builtInDirectory {
            for (file, id) in Self.builtIns {
                let url = dir.appendingPathComponent("\(file).convoy")
                if let data = try? Data(contentsOf: url), let t = try? TemplateFile.decode(data) { result.append(t.template(id: id, builtIn: true)) }
            }
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: userDirectory, includingPropertiesForKeys: nil)) ?? []
        let user: [Template] = files.filter { $0.pathExtension == "convoy" }.compactMap { url in
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let data = try? Data(contentsOf: url), let t = try? TemplateFile.decode(data) else { return nil }
            return t.template(id: id)
        }
        return result + user.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ template: Template) throws {
        guard !template.isBuiltIn, !Self.builtInIDs.contains(template.id) else { throw ConvoyError.builtInTemplate }
        try FileManager.default.createDirectory(at: userDirectory, withIntermediateDirectories: true)
        try TemplateFile(template).encoded().write(to: fileURL(template.id), options: .atomic)
    }

    public func delete(id: UUID) throws {
        guard !Self.builtInIDs.contains(id) else { throw ConvoyError.builtInTemplate }
        let url = fileURL(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    public func importFile(at url: URL) throws -> Template {
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw ConvoyError.invalidTemplateFile(tr("No se pudo leer el archivo.")) }
        return try TemplateFile.decode(data).template()
    }

    public func export(_ template: Template, to url: URL) throws {
        try TemplateFile(template).encoded().write(to: url, options: .atomic)
    }

    private func fileURL(_ id: UUID) -> URL { userDirectory.appendingPathComponent("\(id.uuidString).convoy") }
}

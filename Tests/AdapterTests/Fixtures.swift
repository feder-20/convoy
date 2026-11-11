import Foundation
import ConvoyDomain

enum Fixtures {
    static func f(_ n: String, _ c: [String] = []) -> FolderNode { FolderNode(name: n, children: c.map { FolderNode(name: $0) }) }
    static let proyecto = Template(name: "Proyecto", isBuiltIn: true, folders: [
        f("Acta de constitucion"), f("Stakeholders"), f("Planeacion"),
        f("Seguimiento", ["Actas de reunion", "Informes de avance"]), f("Costos", ["Cotizaciones", "Facturas"]),
        f("Contratos y proveedores"), f("Entregables"), f("Riesgos"), f("Cierre"),
    ])
    static let dest = URL(fileURLWithPath: "/Users/x/Documentos/Proyectos")
    static func request(_ name: String = "Expansión Perú", template: Template = proyecto, include: Bool = true, dest: URL = dest) -> ProjectRequest {
        ProjectRequest(projectName: name, template: template, destination: dest, includeProjectNameInFolders: include)
    }
    static func lines(_ p: CreationPlan) -> [String] { p.folders.map { $0.relativePath.joined(separator: "/") } }
}


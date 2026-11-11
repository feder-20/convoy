import XCTest
import ConvoyDomain
import ConvoyPorts
import ConvoyApplication

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

final class PlanProjectTests: XCTestCase {
    let plan = PlanProject()

    func testExampleFromTheSpecExactly() throws {
        let p = try plan(Fixtures.request())
        XCTAssertEqual(p.rootName, "Expansión Perú")
        XCTAssertEqual(Fixtures.lines(p), [
            "01_Expansión Perú_Acta de constitucion", "02_Expansión Perú_Stakeholders", "03_Expansión Perú_Planeacion",
            "04_Expansión Perú_Seguimiento", "04_Expansión Perú_Seguimiento/Actas de reunion", "04_Expansión Perú_Seguimiento/Informes de avance",
            "05_Expansión Perú_Costos", "05_Expansión Perú_Costos/Cotizaciones", "05_Expansión Perú_Costos/Facturas",
            "06_Expansión Perú_Contratos y proveedores", "07_Expansión Perú_Entregables", "08_Expansión Perú_Riesgos", "09_Expansión Perú_Cierre",
        ])
        XCTAssertEqual(p.folderCount, 13)
        XCTAssertTrue(p.warnings.isEmpty)
    }

    func testWithoutProjectNameInFolders() throws {
        let p = try plan(Fixtures.request(include: false))
        XCTAssertEqual(Fixtures.lines(p).prefix(4), ["01_Acta de constitucion", "02_Stakeholders", "03_Planeacion", "04_Seguimiento"])
        XCTAssertTrue(Fixtures.lines(p).contains("05_Costos/Cotizaciones"), "las subcarpetas solo llevan el tipo")
    }

    func testNumberingGoesPastNineAndKeepsTwoDigits() throws {
        let t = Template(name: "Grande", folders: (1...12).map { Fixtures.f("c\($0)") })
        let p = try plan(Fixtures.request(template: t, include: false))
        XCTAssertEqual(p.folders.map { $0.relativePath[0] }, (1...12).map { String(format: "%02d_c%d", $0, $0) })
        let tooMany = Template(name: "x", folders: (1...100).map { Fixtures.f("c\($0)") })
        XCTAssertThrowsError(try plan(Fixtures.request(template: tooMany))) { XCTAssertEqual($0 as? ConvoyError, .tooManyFolders) }
        XCTAssertNoThrow(try plan(Fixtures.request(template: Template(name: "x", folders: (1...99).map { Fixtures.f("c\($0)") }), include: false)))
    }

    func testNamesAreSanitizedAndWarned() throws {
        let p = try plan(Fixtures.request("Plan: 2026/Q1?"))
        XCTAssertEqual(p.rootName, "Plan- 2026-Q1-")
        XCTAssertEqual(p.warnings, [.replacedCharacters])
        let nfd = try plan(Fixtures.request("Expansio\u{301}n"))
        XCTAssertEqual(nfd.rootName, "Expansión")
        let stripped = try plan(Fixtures.request("Expansión Perú"), stripAccents: true)
        XCTAssertEqual(stripped.rootName, "Expansion Peru")
        XCTAssertEqual(stripped.folders[0].relativePath[0], "01_Expansion Peru_Acta de constitucion")
    }

    func testErrors() {
        XCTAssertThrowsError(try plan(Fixtures.request(""))) { XCTAssertEqual($0 as? ConvoyError, .emptyName) }
        XCTAssertThrowsError(try plan(Fixtures.request("CON"))) { XCTAssertEqual($0 as? ConvoyError, .reservedName("CON")) }
        XCTAssertThrowsError(try plan(Fixtures.request(template: Template(name: "V", folders: [])))) { XCTAssertEqual($0 as? ConvoyError, .emptyTemplate) }
        let dup = Template(name: "D", folders: [Fixtures.f("A", ["x", "X"])])
        XCTAssertThrowsError(try plan(Fixtures.request(template: dup))) { XCTAssertEqual($0 as? ConvoyError, .duplicateFolder("X")) }
        let reservedChild = Template(name: "R", folders: [Fixtures.f("Costos", ["NUL"])])
        XCTAssertThrowsError(try plan(Fixtures.request(template: reservedChild)))
    }

    func testLongSegmentsAreTruncatedWithWarning() throws {
        let p = try plan(Fixtures.request(String(repeating: "x", count: 80), template: Template(name: "T", folders: [Fixtures.f("Seguimiento")])))
        XCTAssertTrue(p.folders[0].relativePath[0].count <= 80)
        XCTAssertTrue(p.warnings.contains(.truncated))
    }

    /// Destino con una longitud tal que la ruta más larga mida exactamente `target` caracteres.
    func destination(forLongest target: Int, template: Template, name: String) throws -> URL {
        let probe = try plan(Fixtures.request(name, template: template, dest: URL(fileURLWithPath: "/a")))
        let base = probe.longestPathLength - "/a".count                    // largo sin el destino
        let destLength = target - base
        let path = "/" + String(repeating: "d", count: destLength - 1)
        let url = URL(fileURLWithPath: path)
        XCTAssertEqual(url.path.count, destLength)
        return url
    }

    func testPathBudgetWarnsAt201AndBlocksAt401() throws {
        let t = Fixtures.proyecto
        let ok200 = try plan(Fixtures.request("Exp", template: t, dest: try destination(forLongest: 200, template: t, name: "Exp")))
        XCTAssertEqual(ok200.longestPathLength, 200); XCTAssertTrue(ok200.warnings.isEmpty)
        let w201 = try plan(Fixtures.request("Exp", template: t, dest: try destination(forLongest: 201, template: t, name: "Exp")))
        XCTAssertEqual(w201.longestPathLength, 201); XCTAssertEqual(w201.warnings, [.longPath(201)])
        let ok400 = try plan(Fixtures.request("Exp", template: t, dest: try destination(forLongest: 400, template: t, name: "Exp")))
        XCTAssertEqual(ok400.warnings, [.longPath(400)])
        XCTAssertThrowsError(try plan(Fixtures.request("Exp", template: t, dest: try destination(forLongest: 401, template: t, name: "Exp")))) {
            XCTAssertEqual($0 as? ConvoyError, .pathTooLong(401))
        }
    }

    func testLongestPathIsMeasuredOnTheDeepestFolder() throws {
        let p = try plan(Fixtures.request("Exp", include: false))
        let expected = "/Users/x/Documentos/Proyectos/Exp/04_Seguimiento/Informes de avance".count
        XCTAssertEqual(p.longestPathLength, expected)
    }
}

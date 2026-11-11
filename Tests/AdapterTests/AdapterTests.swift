import XCTest
import ConvoyDomain
import ConvoyPorts
import ConvoyApplication
import ConvoyAdapters

final class AdapterTests: XCTestCase {
    var tmp: URL!
    var dest: URL!
    let fm = FileManager.default
    var builtInDir: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/BuiltInTemplates") }

    override func setUpWithError() throws {
        tmp = fm.temporaryDirectory.appendingPathComponent("convoy-tests-\(UUID().uuidString)")
        dest = tmp.appendingPathComponent("Proyectos")
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        try? fm.removeItem(at: tmp)
    }

    func listing(_ root: URL) -> [String] {
        ((try? fm.subpathsOfDirectory(atPath: root.path)) ?? []).map { $0.precomposedStringWithCanonicalMapping }.sorted()
    }

    func onlyDirectories(_ root: URL) -> Bool {
        let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey])!
        while let next = en.nextObject() as? URL { if (try? next.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true { return false } }
        return true
    }

    func repo() -> JSONTemplateRepository { JSONTemplateRepository(userDirectory: tmp.appendingPathComponent("templates"), builtInDirectory: builtInDir) }

    // MARK: Escritura atómica

    func testCreatesTheCompleteStructureExactly() async throws {
        let plan = try PlanProject()(Fixtures.request("Expansión Perú", dest: dest))
        let url = try await FileManagerFolderWriter().create(plan, in: dest)
        XCTAssertEqual(url.lastPathComponent, "Expansión Perú")
        let expected = plan.folders.map { $0.relativePath.joined(separator: "/") }.sorted()
        XCTAssertEqual(listing(url), expected, "la vista previa coincide exactamente con el disco")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path).map { $0.precomposedStringWithCanonicalMapping }, ["Expansión Perú"])
        // Solo carpetas, nunca archivos.
        XCTAssertTrue(onlyDirectories(url))
    }

    func testExistingRootIsNeverTouched() async throws {
        let existing = dest.appendingPathComponent("Expansión Perú")
        try fm.createDirectory(at: existing, withIntermediateDirectories: true)
        try "no me toques".write(to: existing.appendingPathComponent("nota.txt"), atomically: true, encoding: .utf8)
        let before = listing(dest)
        do { _ = try await CreateProject(writer: FileManagerFolderWriter(), access: BookmarkLocationAccess(defaults: UserDefaults(suiteName: "t-\(UUID())")!), gate: OpenGate())(Fixtures.request("Expansión Perú", dest: dest)); XCTFail() }
        catch { XCTAssertEqual(error as? ConvoyError, .alreadyExists("Expansión Perú")) }
        XCTAssertEqual(listing(dest), before)
        XCTAssertEqual(try String(contentsOf: existing.appendingPathComponent("nota.txt")), "no me toques")
        // El nombre en NFD también cuenta como existente (APFS los trata igual).
        let nfd = try await FileManagerFolderWriter().exists("Expansio\u{301}n Peru\u{301}", in: dest)
        XCTAssertTrue(nfd)
    }

    func testFailureHalfwayLeavesNothingBehind() async throws {
        let plan = try PlanProject()(Fixtures.request("Falla", dest: dest))
        struct Boom: Error {}
        let before = listing(dest)
        do { _ = try await FileManagerFolderWriter(afterEachFolder: { if $0 == 6 { throw Boom() } }).create(plan, in: dest); XCTFail() }
        catch { XCTAssertEqual(error as? ConvoyError, .creationFailed("Proyectos")) }
        XCTAssertEqual(listing(dest), before, "no queda ninguna carpeta en el destino")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path), [])
    }

    func testRealFailureFromTheFileSystemAlsoLeavesNothing() async throws {
        // Un segmento de 300 caracteres supera el límite de nombre del sistema de archivos (255): falla de verdad a mitad.
        let long = String(repeating: "x", count: 300)
        let plan = CreationPlan(rootName: "Real", folders: [PlannedFolder(relativePath: ["01_a"]), PlannedFolder(relativePath: ["01_a", "b"]),
                                                             PlannedFolder(relativePath: [long])], longestPathLength: 10, warnings: [])
        do { _ = try await FileManagerFolderWriter().create(plan, in: dest); XCTFail() } catch { XCTAssertEqual(error as? ConvoyError, .creationFailed("Proyectos")) }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path), [])
    }

    func testNoPermissionIsReportedAndNothingChanges() async throws {
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dest.path)
        let plan = try PlanProject()(Fixtures.request("Sin permiso", dest: dest))
        do { _ = try await FileManagerFolderWriter().create(plan, in: dest); XCTFail() }
        catch { XCTAssertEqual(error as? ConvoyError, .noPermission(dest), "\(error)") }
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path), [])
    }

    func testTwoCreationsInARowAndRaceOnTheSameName() async throws {
        let writer = FileManagerFolderWriter()
        let a = try PlanProject()(Fixtures.request("Uno", dest: dest)), b = try PlanProject()(Fixtures.request("Dos", dest: dest))
        _ = try await writer.create(a, in: dest); _ = try await writer.create(b, in: dest)
        do { _ = try await writer.create(a, in: dest); XCTFail() } catch { XCTAssertEqual(error as? ConvoyError, .alreadyExists("Uno")) }
        XCTAssertEqual(Set(try fm.contentsOfDirectory(atPath: dest.path)), ["Uno", "Dos"])
    }

    // MARK: Plantillas

    func testBuiltInTemplatesLoadWithStableIdsAndCannotBeSaved() throws {
        let all = try repo().all()
        XCTAssertEqual(all.map(\.name), ["Proyecto", "Campaña", "Tecnología"])
        XCTAssertEqual(all.map(\.folderCount), [13, 10, 12])
        XCTAssertTrue(all.allSatisfy(\.isBuiltIn))
        XCTAssertEqual(try repo().all().map(\.id), all.map(\.id), "los identificadores no cambian entre lecturas")
        XCTAssertThrowsError(try repo().save(all[0])) { XCTAssertEqual($0 as? ConvoyError, .builtInTemplate) }
        XCTAssertThrowsError(try repo().delete(id: all[0].id))
        XCTAssertEqual(all[0].folders.map(\.name), ["Acta de constitucion", "Stakeholders", "Planeacion", "Seguimiento", "Costos", "Contratos y proveedores", "Entregables", "Riesgos", "Cierre"])
    }

    func testUserTemplatesPersistAcrossInstances() throws {
        let t = Template(name: "Mía ñandú", folders: [FolderNode(name: "A", children: [FolderNode(name: "a1")]), FolderNode(name: "B")])
        try repo().save(t)
        let reopened = try repo().all().first { $0.id == t.id }
        XCTAssertEqual(reopened?.name, "Mía ñandú")
        XCTAssertEqual(reopened?.folders.map(\.name), ["A", "B"])
        XCTAssertEqual(reopened?.folders[0].children.map(\.name), ["a1"])
        XCTAssertEqual(reopened?.isBuiltIn, false)
        var edited = t; edited.addFolder(named: "C")
        try repo().save(edited)
        XCTAssertEqual(try repo().all().first { $0.id == t.id }?.folders.count, 3)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: tmp.appendingPathComponent("templates").path), ["\(t.id.uuidString).convoy"], "un archivo por plantilla")
        try repo().delete(id: t.id)
        XCTAssertNil(try repo().all().first { $0.id == t.id })
    }

    func testExportImportRoundTripAndFileFormat() throws {
        let original = try repo().all()[0]
        let file = tmp.appendingPathComponent("proyecto.convoy")
        try repo().export(original, to: file)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertEqual(json["name"] as? String, "Proyecto")
        XCTAssertNil(json["id"]); XCTAssertNil(json["isBuiltIn"])
        let folders = try XCTUnwrap(json["folders"] as? [[String: Any]])
        XCTAssertEqual(folders[3]["name"] as? String, "Seguimiento")
        XCTAssertNil(folders[0]["children"])
        let imported = try repo().importFile(at: file)
        XCTAssertEqual(imported.folders.map(\.name), original.folders.map(\.name))
        XCTAssertEqual(imported.folders[3].children.map(\.name), ["Actas de reunion", "Informes de avance"])
        XCTAssertNotEqual(imported.id, original.id)
    }

    func testInvalidTemplateFilesAreRejectedWithClearErrors() throws {
        func write(_ s: String) throws -> URL { let u = tmp.appendingPathComponent("x-\(UUID()).convoy"); try s.write(to: u, atomically: true, encoding: .utf8); return u }
        let cases = [
            "esto no es json", "{}", #"{"schemaVersion":1}"#, #"{"schemaVersion":1,"name":"","folders":[]}"#,
            #"{"schemaVersion":2,"name":"X","folders":[]}"#, #"{"schemaVersion":0,"name":"X","folders":[]}"#,
            #"{"schemaVersion":1,"name":"X","folders":[{"name":"  "}]}"#,
            #"{"schemaVersion":1,"name":"X","folders":[{"name":"A","children":[{"name":""}]}]}"#,
            #"{"schemaVersion":1,"name":"X","folders":[{"name":"A","children":[{"name":"B","children":[{"name":"C"}]}]}]}"#,
        ]
        for c in cases {
            XCTAssertThrowsError(try repo().importFile(at: try write(c)), c) { error in
                guard case ConvoyError.invalidTemplateFile = error else { return XCTFail("\(c): \(error)") }
            }
        }
        XCTAssertThrowsError(try repo().importFile(at: tmp.appendingPathComponent("no-existe.convoy")))
        XCTAssertNoThrow(try repo().importFile(at: try write(#"{"schemaVersion":1,"name":"Vacía","folders":[]}"#)))
    }

    func testManageTemplatesWithRealRepository() throws {
        let manage = ManageTemplates(repository: repo())
        let copy = try manage.duplicate(try repo().all()[0])
        XCTAssertEqual(copy.name, "Proyecto copia")
        XCTAssertEqual(try manage.all().count, 4)
        let file = tmp.appendingPathComponent("c.convoy")
        try manage.export(copy, to: file)
        XCTAssertEqual(try manage.importFile(at: file).name, "Proyecto copia 2")
    }

    // MARK: Ubicaciones

    func testRecentsDefaultAndCap() throws {
        let defaults = UserDefaults(suiteName: "convoy-test-\(UUID())")!
        let access = BookmarkLocationAccess(defaults: defaults, maxRecent: 3)
        let dirs = try (1...5).map { i -> URL in let u = tmp.appendingPathComponent("d\(i)"); try fm.createDirectory(at: u, withIntermediateDirectories: true); return u }
        for d in dirs { try access.remember(d) }
        XCTAssertEqual(access.recent().map(\.lastPathComponent), ["d5", "d4", "d3"], "los más recientes primero, con tope")
        try access.remember(dirs[3])
        XCTAssertEqual(access.recent().map(\.lastPathComponent), ["d4", "d5", "d3"], "sin repetidos: sube al principio")
        XCTAssertNil(access.defaultLocation())
        try access.setDefaultLocation(dirs[0])
        XCTAssertEqual(access.defaultLocation()?.lastPathComponent, "d1")
        try fm.removeItem(at: dirs[0])
        XCTAssertNil(access.defaultLocation(), "una carpeta que ya no existe no se ofrece")
        try fm.removeItem(at: dirs[4])
        XCTAssertFalse(access.recent().contains { $0.lastPathComponent == "d5" })
    }

    func testEndToEndWithRealAdapters() async throws {
        let defaults = UserDefaults(suiteName: "convoy-e2e-\(UUID())")!
        let access = BookmarkLocationAccess(defaults: defaults)
        let template = try repo().all()[1]                                   // Campaña
        let result = try await CreateProject(writer: FileManagerFolderWriter(), access: access, gate: OpenGate())(
            ProjectRequest(projectName: "Lanzamiento: Otoño", template: template, destination: dest, includeProjectNameInFolders: false))
        XCTAssertEqual(result.url.lastPathComponent, "Lanzamiento- Otoño")
        XCTAssertEqual(result.folderCount, 10)
        XCTAssertTrue(listing(result.url).contains("04_Piezas/En revision"))
        XCTAssertEqual(access.recent().map(\.lastPathComponent), ["Proyectos"])
    }
}

/// Hallazgos H1 y H3 con el escritor y el repositorio reales.
final class SecurityAdapterTests: XCTestCase {
    var tmp: URL!, dest: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        tmp = fm.temporaryDirectory.appendingPathComponent("convoy-sec-\(UUID().uuidString)")
        dest = tmp.appendingPathComponent("Destino")
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? fm.removeItem(at: tmp) }

    func everything() -> [String] { ((try? fm.subpathsOfDirectory(atPath: tmp.path)) ?? []).sorted() }

    func testHostileNamesNeverCreateAnythingOutsideTheDestination() async throws {
        let access = BookmarkLocationAccess(defaults: UserDefaults(suiteName: "t-\(UUID())")!)
        let run = CreateProject(writer: FileManagerFolderWriter(), access: access, gate: OpenGate())
        let hostile = Template(name: "H", folders: [
            FolderNode(name: "../\u{0338}ESC", children: [FolderNode(name: "..\\\u{0301}x"), FolderNode(name: "/\u{200D}/../..")]),
            FolderNode(name: "../../fuera"),
        ])
        var n = 0
        for name in ["../\u{0338}ESC", "/\u{0301}../x"] {
            for include in [false, true] {
                n += 1
                let r = try await run(ProjectRequest(projectName: name + String(n), template: hostile, destination: dest, includeProjectNameInFolders: include))
                XCTAssertEqual(r.url.standardizedFileURL.deletingLastPathComponent().path, dest.standardizedFileURL.path)
            }
        }
        let outside = everything().filter { !$0.hasPrefix("Destino") }
        XCTAssertEqual(outside, [], "nada fuera del destino: \(outside)")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path).count, 4)
    }

    func testWriterRejectsForgedPlansThatEscape() async throws {
        let writer = FileManagerFolderWriter()
        let plans = [
            CreationPlan(rootName: "../escape", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "a/b", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "..", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: ".", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "a\0b", folders: [], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "Ok", folders: [PlannedFolder(relativePath: ["..", "x"])], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "Ok", folders: [PlannedFolder(relativePath: ["../../zz"])], longestPathLength: 0, warnings: []),
            CreationPlan(rootName: "Ok", folders: [PlannedFolder(relativePath: ["a", "."])], longestPathLength: 0, warnings: []),
        ]
        for p in plans {
            do { _ = try await writer.create(p, in: dest); XCTFail("debía rechazar \(p.rootName) \(p.folders.map(\.relativePath))") }
            catch { XCTAssertEqual(error as? ConvoyError, .creationFailed("Destino")) }
        }
        XCTAssertThrowsError(try writer.exists("../x", in: dest))
        XCTAssertEqual(everything(), ["Destino"], "no se creó nada")
    }

    func testTemporaryRootIsRemovedAfterSuccessAndFailure() async throws {
        let before = Set((try? fm.contentsOfDirectory(atPath: fm.temporaryDirectory.path)) ?? [])
        let w = FileManagerFolderWriter(afterEachFolder: { if $0 == 1 { throw ConvoyError.creationFailed("x") } })
        _ = try? await w.create(CreationPlan(rootName: "R", folders: [PlannedFolder(relativePath: ["a"]), PlannedFolder(relativePath: ["b"])], longestPathLength: 0, warnings: []), in: dest)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path), [])
        _ = before
    }

    // MARK: H3

    func repo() -> JSONTemplateRepository { JSONTemplateRepository(userDirectory: tmp.appendingPathComponent("t"), builtInDirectory: nil) }
    func write(_ s: String) throws -> URL { let u = tmp.appendingPathComponent("x-\(UUID()).convoy"); try s.write(to: u, atomically: true, encoding: .utf8); return u }
    func template(top: Int = 1, children: Int = 0, folderName: String = "A", name: String = "T") -> String {
        let kids = (0..<children).map { #"{"name":"c\#($0)"}"# }.joined(separator: ",")
        let tops = (0..<top).map { #"{"name":"\#(folderName)\#($0)","children":[\#(kids)]}"# }.joined(separator: ",")
        return #"{"schemaVersion":1,"name":"\#(name)","folders":[\#(tops)]}"#
    }

    func testImportLimits() throws {
        XCTAssertNoThrow(try repo().importFile(at: write(template(top: 99, children: 99))))
        let bad = [template(top: 100), template(top: 1, children: 100), template(folderName: String(repeating: "x", count: 256)),
                   template(name: String(repeating: "n", count: 81))]
        for c in bad {
            XCTAssertThrowsError(try repo().importFile(at: write(c))) { guard case ConvoyError.invalidTemplateFile = $0 else { return XCTFail("\($0)") } }
        }
        XCTAssertNoThrow(try repo().importFile(at: write(template(name: String(repeating: "n", count: 80)))))
    }

    func testImportRejectsBigAndNonRegularFilesBeforeReading() throws {
        let big = tmp.appendingPathComponent("big.convoy")
        try Data(count: 1_048_577).write(to: big)
        XCTAssertThrowsError(try repo().importFile(at: big)) { XCTAssertTrue($0.localizedDescription.contains("1 MB")) }
        // Un archivo de relleno con JSON válido pero enorme también se rechaza por tamaño.
        let padded = tmp.appendingPathComponent("padded.convoy")
        try (template() + String(repeating: " ", count: 1_100_000)).write(to: padded, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try repo().importFile(at: padded))
        XCTAssertThrowsError(try repo().importFile(at: dest)) { XCTAssertTrue($0.localizedDescription.contains("normal")) }
        let fifo = tmp.appendingPathComponent("fifo.convoy")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        XCTAssertThrowsError(try repo().importFile(at: fifo))   // no se queda bloqueado leyendo
    }
}

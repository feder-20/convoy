import XCTest
import ConvoyDomain
import ConvoyPorts
import ConvoyApplication

final class FakeWriter: FolderWriter, @unchecked Sendable {
    var existing: Set<String> = []
    var created: [CreationPlan] = []
    var failWith: Error?
    func exists(_ name: String, in parent: URL) throws -> Bool { existing.contains(name) }
    func create(_ plan: CreationPlan, in parent: URL) async throws -> URL {
        if let failWith { throw failWith }
        created.append(plan)
        return parent.appendingPathComponent(plan.rootName)
    }
}

final class FakeAccess: LocationAccess, @unchecked Sendable {
    var remembered: [URL] = [], accessed: [URL] = []
    var denied = false
    func withAccess<T: Sendable>(to url: URL, _ body: () async throws -> T) async throws -> T {
        if denied { throw ConvoyError.noPermission(url) }
        accessed.append(url)
        return try await body()
    }
    func remember(_ url: URL) throws { remembered.append(url) }
    func recent() -> [URL] { remembered }
    func defaultLocation() -> URL? { nil }
    func setDefaultLocation(_ url: URL) throws {}
}

final class FakeRepo: TemplateRepository, @unchecked Sendable {
    var store: [Template] = []
    var saved: [Template] = []
    func all() throws -> [Template] { store }
    func save(_ t: Template) throws { saved.append(t); store.removeAll { $0.id == t.id }; store.append(t) }
    func delete(id: UUID) throws { store.removeAll { $0.id == id } }
    func importFile(at url: URL) throws -> Template { Template(name: "Importada", folders: [FolderNode(name: "A")]) }
    func export(_ t: Template, to url: URL) throws {}
}

final class CreateProjectTests: XCTestCase {
    func make() -> (CreateProject, FakeWriter, FakeAccess) {
        let w = FakeWriter(), a = FakeAccess()
        return (CreateProject(writer: w, access: a), w, a)
    }

    func testCreatesWithAccessAndRemembersDestination() async throws {
        let (run, w, a) = make()
        let r = try await run(Fixtures.request())
        XCTAssertEqual(r.url.lastPathComponent, "Expansión Perú")
        XCTAssertEqual(r.folderCount, 13)
        XCTAssertEqual(w.created.count, 1)
        XCTAssertEqual(a.accessed, [Fixtures.dest]); XCTAssertEqual(a.remembered, [Fixtures.dest])
    }

    func testExistingRootCreatesNothing() async {
        let (run, w, a) = make()
        w.existing = ["Expansión Perú"]
        do { _ = try await run(Fixtures.request()); XCTFail() }
        catch { XCTAssertEqual(error as? ConvoyError, .alreadyExists("Expansión Perú")) }
        XCTAssertTrue(w.created.isEmpty); XCTAssertTrue(a.remembered.isEmpty)
    }

    func testInvalidRequestNeverTouchesTheDiskNorAsksAccess() async {
        let (run, w, a) = make()
        do { _ = try await run(Fixtures.request("")); XCTFail() } catch { XCTAssertEqual(error as? ConvoyError, .emptyName) }
        XCTAssertTrue(w.created.isEmpty); XCTAssertTrue(a.accessed.isEmpty)
    }

    func testPermissionAndWriterFailuresPropagateWithoutRemembering() async {
        let (run, w, a) = make()
        a.denied = true
        do { _ = try await run(Fixtures.request()); XCTFail() } catch { XCTAssertEqual(error as? ConvoyError, .noPermission(Fixtures.dest)) }
        a.denied = false
        w.failWith = ConvoyError.creationFailed("Proyectos")
        do { _ = try await run(Fixtures.request()); XCTFail() } catch { XCTAssertEqual(error as? ConvoyError, .creationFailed("Proyectos")) }
        XCTAssertTrue(a.remembered.isEmpty)
    }
}

final class ManageTemplatesTests: XCTestCase {
    func testBuiltInsCannotBeChangedOrDeletedButCanBeDuplicated() throws {
        let repo = FakeRepo(); repo.store = [Fixtures.proyecto]
        let manage = ManageTemplates(repository: repo)
        XCTAssertThrowsError(try manage.update(Fixtures.proyecto)) { XCTAssertEqual($0 as? ConvoyError, .builtInTemplate) }
        XCTAssertThrowsError(try manage.delete(Fixtures.proyecto)) { XCTAssertEqual($0 as? ConvoyError, .builtInTemplate) }
        let copy = try manage.duplicate(Fixtures.proyecto)
        XCTAssertEqual(copy.name, "Proyecto copia"); XCTAssertFalse(copy.isBuiltIn)
        XCTAssertEqual(try manage.duplicate(Fixtures.proyecto).name, "Proyecto copia 2")
        XCTAssertEqual(try manage.all().count, 3)
        XCTAssertNoThrow(try manage.update(copy))
        try manage.delete(copy)
        XCTAssertEqual(try manage.all().count, 2)
    }

    func testCreateEmptyAndImportGetUniqueNames() throws {
        let repo = FakeRepo()
        let manage = ManageTemplates(repository: repo)
        XCTAssertEqual(try manage.createEmpty(named: "").name, "Nueva plantilla")
        XCTAssertEqual(try manage.createEmpty(named: "Nueva plantilla").name, "Nueva plantilla 2")
        let a = try manage.importFile(at: URL(fileURLWithPath: "/x.convoy"))
        let b = try manage.importFile(at: URL(fileURLWithPath: "/x.convoy"))
        XCTAssertEqual([a.name, b.name], ["Importada", "Importada 2"])
        XCTAssertFalse(a.isBuiltIn)
    }
}

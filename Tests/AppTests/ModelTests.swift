import XCTest
import ConvoyDomain
import ConvoyPorts
import ConvoyAdapters
import ConvoyApplication
import ConvoyLicensing
@testable import ConvoyApp

final class FakeRevealer: FinderRevealer, @unchecked Sendable {
    var revealed: [URL] = []
    func reveal(_ url: URL) { revealed.append(url) }
}

@MainActor
final class ModelTests: XCTestCase {
    var tmp: URL!
    var dest: URL!
    var revealer: FakeRevealer!
    var builtIns: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/BuiltInTemplates") }
    let fm = FileManager.default

    override func setUp() async throws {
        tmp = fm.temporaryDirectory.appendingPathComponent("convoy-app-\(UUID().uuidString)")
        dest = tmp.appendingPathComponent("Proyectos")
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        revealer = FakeRevealer()
        for k in [Prefs.selectedTemplateKey, Prefs.stripAccentsKey, Prefs.includeNameKey] { UserDefaults.standard.removeObject(forKey: k) }
    }
    override func tearDown() async throws { try? fm.removeItem(at: tmp); UserDefaults.standard.removeObject(forKey: Prefs.stripAccentsKey) }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
    var opened: [URL] = []
    func makeTrial(now: Date = ModelTests.date(2026, 12, 1), store: KeyValueStore = MemoryStore()) -> TrialController {
        TrialController(manager: TrialManager(store: store, now: { now }), opener: { _ in })
    }

    func makeModel(trial: TrialController? = nil, validator: DestinationValidator = DestinationValidator()) -> AppModel {
        let m = AppModel(repository: JSONTemplateRepository(userDirectory: tmp.appendingPathComponent("templates"), builtInDirectory: builtIns),
                         access: BookmarkLocationAccess(defaults: UserDefaults(suiteName: "convoy-m-\(UUID())")!),
                         revealer: revealer, trial: trial ?? makeTrial(), destinationValidator: validator)
        m.setDestination(dest)
        return m
    }

    func testStartsWithBuiltInsAndDefaultTemplateSelected() {
        let m = makeModel()
        XCTAssertEqual(m.templates.map(\.name), ["Proyecto", "Campaña", "Tecnología"])
        XCTAssertEqual(m.selectedTemplate?.name, "Proyecto", "«Proyecto» es la plantilla por defecto")
        XCTAssertTrue(m.includeName)
    }

    func testButtonIsDisabledWithoutNameAndPreviewShowsPlaceholder() {
        let m = makeModel()
        XCTAssertFalse(m.canCreate)
        XCTAssertTrue(m.isPlaceholder)
        guard case .success(let plan) = m.planResult else { return XCTFail() }
        XCTAssertEqual(plan.rootName, "Nombre del proyecto")
        XCTAssertTrue(m.warnings.isEmpty, "sin nombre no se muestra error, solo el marcador")
        m.projectName = "   "
        XCTAssertFalse(m.canCreate)
        m.projectName = "Expansión Perú"
        XCTAssertTrue(m.canCreate)
    }

    func testPreviewMatchesWhatIsCreatedOnDisk() async throws {
        let m = makeModel()
        m.projectName = "Expansión Perú"
        guard case .success(let plan) = m.planResult else { return XCTFail() }
        await m.create()
        guard case .created(let url, let count, _) = m.phase else { return XCTFail("\(String(describing: m.message))") }
        XCTAssertEqual(count, 13)
        let onDisk = try fm.subpathsOfDirectory(atPath: url.path).map { $0.precomposedStringWithCanonicalMapping }.sorted()
        XCTAssertEqual(onDisk, plan.folders.map { $0.relativePath.joined(separator: "/") }.sorted())
        m.revealCreated()
        XCTAssertEqual(revealer.revealed, [url])
    }

    func testCreateAnotherResetsTheForm() async {
        let m = makeModel()
        m.projectName = "Uno"
        await m.create()
        m.startAnother()
        XCTAssertEqual(m.phase, .editing); XCTAssertEqual(m.projectName, "")
        XCTAssertFalse(m.canCreate)
        m.projectName = "Dos"
        await m.create()
        XCTAssertEqual(Set(try! fm.contentsOfDirectory(atPath: dest.path)), ["Uno", "Dos"])
    }

    func testEditingAfterCreationReturnsToTheForm() async {
        let m = makeModel()
        m.projectName = "Uno"
        await m.create()
        m.projectName = "Uno2"
        XCTAssertEqual(m.phase, .editing)
    }

    func testExistingFolderShowsMessageOffersToRevealAndTouchesNothing() async throws {
        let m = makeModel()
        try fm.createDirectory(at: dest.appendingPathComponent("Ya existe"), withIntermediateDirectories: true)
        m.projectName = "Ya existe"
        await m.create()
        XCTAssertEqual(m.message, "Ya hay una carpeta llamada «Ya existe» aquí.")
        XCTAssertEqual(m.phase, .editing)
        XCTAssertEqual(m.existingURL?.lastPathComponent, "Ya existe")
        m.revealExisting()
        XCTAssertEqual(revealer.revealed.first?.lastPathComponent, "Ya existe")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.appendingPathComponent("Ya existe").path), [])
        m.projectName = "Otro"
        XCTAssertNil(m.message); XCTAssertNil(m.existingURL)
    }

    func testWarningsAndBlockedStates() {
        let m = makeModel()
        m.projectName = "Plan: 2026?"
        XCTAssertEqual(m.warnings, ["Se reemplazaron caracteres que Windows no permite."])
        XCTAssertTrue(m.canCreate)
        m.projectName = "CON"
        XCTAssertFalse(m.canCreate)
        XCTAssertEqual(m.warnings, ["«CON» es un nombre que Windows no permite."])
        m.projectName = String(repeating: "a", count: 80)
        let long = try? XCTUnwrap({ () -> URL? in URL(fileURLWithPath: "/" + String(repeating: "d", count: 330)) }())
        m.setDestination(long!)
        XCTAssertFalse(m.canCreate, "bloqueado por encima de 400 caracteres")
        XCTAssertTrue(m.warnings.first?.contains("más larga tendría") == true)
    }

    func testStripAccentsPreferenceChangesTheFolderNames() async throws {
        UserDefaults.standard.set(true, forKey: Prefs.stripAccentsKey)
        let m = makeModel()
        m.projectName = "Expansión Perú"
        await m.create()
        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Expansion Peru").path))
    }

    func testTemplateEditingAutosavesAndSurvivesRestart() throws {
        let m = makeModel()
        m.duplicateSelected()
        XCTAssertEqual(m.selectedTemplate?.name, "Proyecto copia")
        XCTAssertEqual(m.selectedTemplate?.isBuiltIn, false)
        m.edit { $0.addFolder(named: "Riesgos legales") }
        let first = m.selectedTemplate!.folders[0].id
        m.edit { $0.move(folder: first, by: 1) }
        m.edit { $0.rename(folder: first, to: "Acta") }
        m.edit { $0.name = "Mi proyecto" }
        let id = m.selectedTemplateID!
        let reopened = makeModel()
        let t = try XCTUnwrap(reopened.templates.first { $0.id == id })
        XCTAssertEqual(t.name, "Mi proyecto")
        XCTAssertEqual(t.folders.last?.name, "Riesgos legales")
        XCTAssertEqual(t.folders[1].name, "Acta")
        XCTAssertEqual(reopened.selectedTemplateID, id, "la plantilla elegida se recuerda")
    }

    func testBuiltInTemplatesAreProtectedAndUserOnesCanBeDeleted() {
        let m = makeModel()
        m.edit { $0.addFolder(named: "X") }
        XCTAssertEqual(m.message, "Las plantillas de fábrica no se pueden cambiar. Duplícala para editarla.")
        XCTAssertEqual(m.selectedTemplate?.folderCount, 13)
        m.deleteSelected()
        XCTAssertEqual(m.templates.count, 3, "no se elimina una plantilla de fábrica")
        m.newTemplate()
        XCTAssertEqual(m.templates.count, 4)
        XCTAssertFalse(m.canCreate)
        m.projectName = "X"
        XCTAssertFalse(m.canCreate, "una plantilla vacía no permite crear")
        XCTAssertEqual(m.warnings, ["La plantilla no tiene carpetas."])
        m.deleteSelected()
        XCTAssertEqual(m.templates.count, 3)
        XCTAssertEqual(m.selectedTemplate?.name, "Proyecto")
    }

    func testExportImportThroughTheModel() throws {
        let m = makeModel()
        let file = tmp.appendingPathComponent("p.convoy")
        m.exportSelected(to: file)
        m.importTemplate(from: file)
        XCTAssertEqual(m.selectedTemplate?.name, "Proyecto 2")
        XCTAssertEqual(m.selectedTemplate?.folderCount, 13)
        m.importTemplate(from: tmp.appendingPathComponent("no-existe.convoy"))
        XCTAssertTrue(m.message?.contains("no es válido") == true)
    }

    func testFinderRequestSetsFolderAndFocus() {
        let m = makeModel(validator: Self.okValidator)
        m.tab = .templates
        let before = m.focusTick
        m.prepare(requestedPath: "/Users/x/Proyectos")
        XCTAssertEqual(m.tab, .newProject); XCTAssertEqual(m.destination.path, "/Users/x/Proyectos")
        XCTAssertEqual(m.focusTick, before + 1)
    }

    static let okValidator = DestinationValidator(home: "/Users/x", probe: .init(isDirectory: { _ in true }, isWritable: { _ in true }, resolve: { $0 }))

    func testLinkedDestinationShowsPersistentNoticeAndBlocksCreationUntilConfirmed() {
        let m = makeModel(validator: Self.okValidator)
        m.projectName = ""
        m.prepare(requestedPath: "/Users/x/Proyectos")
        XCTAssertEqual(m.linkedDestination?.path, "/Users/x/Proyectos")
        m.projectName = "Algo"
        XCTAssertNotNil(m.linkedDestination, "escribir un nombre no confirma el destino")
        XCTAssertFalse(m.canCreate)
        m.confirmLinkedDestination()
        XCTAssertNil(m.linkedDestination); XCTAssertTrue(m.canCreate)
        m.prepare(requestedPath: "/Users/x/Otra")
        XCTAssertEqual(m.destination.path, "/Users/x/Proyectos", "no se cambia el destino mientras se escribe un nombre")
        XCTAssertNil(m.linkedDestination); XCTAssertNotNil(m.linkError)
        m.startAnother()
        m.prepare(requestedPath: "/Users/x/Otra")
        XCTAssertNotNil(m.linkedDestination)
        m.setDestination(dest)
        XCTAssertNil(m.linkedDestination, "elegir otra carpeta retira el aviso")
    }

    func testHostileLinkDestinationsAreRejectedAndDestinationIsKept() {
        let m = makeModel(validator: Self.okValidator)
        for bad in ["/", "/etc", "/System/Library", "/Users/x/Library/Preferences", "/Users/x/.ssh", "relativa", "/Users/x/../../etc", "/Users/x/.oculta"] {
            m.prepare(requestedPath: bad)
            XCTAssertEqual(m.destination, dest, bad)
            XCTAssertNil(m.linkedDestination, bad)
            XCTAssertNotNil(m.linkError, bad)
        }
    }

    func testExpiredTrialBlocksCreationWithoutTouchingDiskAndNotifies() async throws {
        let m = makeModel(trial: makeTrial(now: Self.date(2027, 2, 10)))
        var notified = false
        m.onTrialExpired = { notified = true }
        m.projectName = "No debe crearse"
        await m.create()
        XCTAssertTrue(notified)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dest.path), [])
        XCTAssertEqual(m.message, ConvoyError.trialExpired.localizedDescription)
        let t = makeTrial(now: Self.date(2027, 2, 9))
        let ok = makeModel(trial: t); ok.projectName = "Sí se crea"
        await ok.create()
        XCTAssertTrue(fm.fileExists(atPath: dest.appendingPathComponent("Sí se crea").path))
    }

    func testPreviewImportDoesNotSaveAnything() throws {
        let m = makeModel()
        let file = tmp.appendingPathComponent("x.convoy")
        m.selectedTemplateID = m.templates.first?.id
        m.exportSelected(to: file)
        let before = m.templates.count
        guard case .success(let t) = m.previewImport(from: file) else { return XCTFail() }
        XCTAssertEqual(t.name, "Proyecto"); XCTAssertEqual(m.templates.count, before)
        guard case .failure = m.previewImport(from: tmp.appendingPathComponent("no.convoy")) else { return XCTFail() }
    }

    func testHotKeyDefaultsToOptionCommandN() {
        let d = UserDefaults.standard
        let saved = d.object(forKey: Prefs.hotKeyCodeKey)
        defer { d.set(saved, forKey: Prefs.hotKeyCodeKey) }
        d.removeObject(forKey: Prefs.hotKeyCodeKey)
        XCTAssertEqual(Prefs.hotKeyLabel, "⌥⌘N")
    }
}

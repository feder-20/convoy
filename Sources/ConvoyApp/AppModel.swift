import AppKit
import SwiftUI
import Observation
import ConvoyDomain
import ConvoyPorts
import ConvoyApplication
import ConvoyAdapters

enum MainTab: Hashable { case newProject, templates }

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable { case editing, created(url: URL, folderCount: Int, where_: String) }

    var tab: MainTab = .newProject
    var projectName = "" {
        didSet { if case .created = phase { phase = .editing }; message = nil; existingURL = nil }
    }
    private(set) var templates: [Template] = []
    var selectedTemplateID: UUID? { didSet { Prefs.selectedTemplate = selectedTemplateID; message = nil } }
    private(set) var destination: URL
    private(set) var defaultDestination: URL
    private(set) var recents: [URL] = []
    var includeName: Bool = Prefs.includeName { didSet { Prefs.includeName = includeName } }
    private(set) var phase: Phase = .editing
    var message: String?
    /// Carpeta que ya existe (para ofrecer abrirla).
    private(set) var existingURL: URL?
    private(set) var isCreating = false
    var focusTick = 0

    private let access: LocationAccess
    private let manage: ManageTemplates
    private let createProject: CreateProject
    private let revealer: FinderRevealer
    private let plan = PlanProject()

    init(repository: TemplateRepository = JSONTemplateRepository(), access: LocationAccess = BookmarkLocationAccess(),
         writer: FolderWriter = FileManagerFolderWriter(), revealer: FinderRevealer = NSWorkspaceRevealer()) {
        self.access = access
        self.manage = ManageTemplates(repository: repository)
        self.createProject = CreateProject(writer: writer, access: access)
        self.revealer = revealer
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let start = access.defaultLocation() ?? documents
        self.defaultDestination = start
        self.destination = start
        reloadTemplates()
        recents = access.recent()
    }

    // MARK: Datos derivados

    var selectedTemplate: Template? { templates.first { $0.id == selectedTemplateID } }
    var trimmedName: String { projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isPlaceholder: Bool { trimmedName.isEmpty }
    var stripAccents: Bool { Prefs.stripAccents }

    /// Lo que se crearía ahora; con el nombre vacío se usa el marcador «Nombre del proyecto» (convoy.md §4.3).
    var planResult: Result<CreationPlan, ConvoyError> {
        guard let template = selectedTemplate else { return .failure(.emptyTemplate) }
        let name = isPlaceholder ? L("Nombre del proyecto") : projectName
        do {
            return .success(try plan(ProjectRequest(projectName: name, template: template, destination: destination,
                                                    includeProjectNameInFolders: includeName), stripAccents: stripAccents))
        } catch let e as ConvoyError { return .failure(e) } catch { return .failure(.creationFailed(destination.lastPathComponent)) }
    }

    var canCreate: Bool {
        if isPlaceholder || isCreating { return false }
        if case .success = planResult { return true } else { return false }
    }

    var warnings: [String] {
        switch planResult {
        case .success(let p): return p.warnings.map(\.message)
        case .failure(let e): return isPlaceholder && e == .emptyName ? [] : [e.localizedDescription]
        }
    }

    // MARK: Plantillas

    func reloadTemplates() {
        templates = (try? manage.all()) ?? []
        if selectedTemplate == nil { selectedTemplateID = Prefs.selectedTemplate.flatMap { id in templates.first { $0.id == id }?.id } ?? templates.first?.id }
    }

    /// Aplica un cambio a la plantilla propia seleccionada y lo guarda al instante.
    func edit(_ change: (inout Template) -> Void) {
        guard var t = selectedTemplate else { return }
        guard !t.isBuiltIn else { message = ConvoyError.builtInTemplate.localizedDescription; return }
        change(&t)
        do { try manage.update(t) } catch { message = error.localizedDescription; return }
        if let i = templates.firstIndex(where: { $0.id == t.id }) { templates[i] = t }
        message = nil
    }

    func duplicateSelected() {
        guard let t = selectedTemplate else { return }
        do { let copy = try manage.duplicate(t); reloadTemplates(); selectedTemplateID = copy.id }
        catch { message = error.localizedDescription }
    }

    func newTemplate() {
        do { let t = try manage.createEmpty(named: L("Nueva plantilla")); reloadTemplates(); selectedTemplateID = t.id }
        catch { message = error.localizedDescription }
    }

    func deleteSelected() {
        guard let t = selectedTemplate else { return }
        do { try manage.delete(t); selectedTemplateID = nil; reloadTemplates() } catch { message = error.localizedDescription }
    }

    func importTemplate(from url: URL) {
        do { let t = try manage.importFile(at: url); reloadTemplates(); selectedTemplateID = t.id; message = nil }
        catch { message = error.localizedDescription }
    }

    func exportSelected(to url: URL) {
        guard let t = selectedTemplate else { return }
        do { try manage.export(t, to: url) } catch { message = error.localizedDescription }
    }

    func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .init(filenameExtension: "convoy") ?? .json]
        panel.allowsMultipleSelection = false
        panel.prompt = L("Importar")
        if panel.runModal() == .OK, let url = panel.url { importTemplate(from: url) }
    }

    func chooseExportFile() {
        guard let t = selectedTemplate else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(t.name).convoy"
        panel.prompt = L("Exportar")
        if panel.runModal() == .OK, let url = panel.url { exportSelected(to: url) }
    }

    // MARK: Destino

    func setDestination(_ url: URL) { destination = url; phase = .editing; message = nil; existingURL = nil }

    func chooseOtherFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destination
        panel.prompt = L("Elegir")
        if panel.runModal() == .OK, let url = panel.url {
            setDestination(url)
            try? access.remember(url)
            recents = access.recent()
        }
    }

    func makeDestinationDefault() {
        try? access.setDefaultLocation(destination)
        defaultDestination = destination
    }

    // MARK: Crear

    func create() async {
        guard canCreate, let template = selectedTemplate else { return }
        isCreating = true
        defer { isCreating = false }
        let request = ProjectRequest(projectName: projectName, template: template, destination: destination, includeProjectNameInFolders: includeName)
        do {
            let r = try await createProject(request, stripAccents: stripAccents)
            phase = .created(url: r.url, folderCount: r.folderCount, where_: breadcrumb(destination))
            message = nil
            recents = access.recent()
        } catch let e as ConvoyError {
            handle(e)
        } catch {
            message = ConvoyError.creationFailed(destination.lastPathComponent).localizedDescription
        }
    }

    private func handle(_ error: ConvoyError) {
        message = error.localizedDescription
        switch error {
        case .alreadyExists(let name): existingURL = destination.appendingPathComponent(name)
        case .noPermission:
            // Se pide acceso a la carpeta con el panel del sistema (convoy.md §4.3).
            let panel = NSOpenPanel()
            panel.canChooseFiles = false; panel.canChooseDirectories = true
            panel.directoryURL = destination
            panel.message = message
            panel.prompt = L("Permitir")
            if panel.runModal() == .OK, let url = panel.url { setDestination(url); Task { await create() } }
        default: break
        }
    }

    func revealCreated() { if case .created(let url, _, _) = phase { revealer.reveal(url) } }
    func revealExisting() { if let existingURL { revealer.reveal(existingURL) } }

    /// «Crear otro»: vuelve al formulario con el nombre vacío.
    func startAnother() {
        phase = .editing; projectName = ""; message = nil; existingURL = nil; focusTick += 1
    }

    /// Lo que pide el clic derecho del Finder: carpeta y foco en el nombre.
    func prepare(destination url: URL?) {
        tab = .newProject
        if let url { setDestination(url) }
        if case .created = phase { phase = .editing; projectName = "" }
        focusTick += 1
    }
}

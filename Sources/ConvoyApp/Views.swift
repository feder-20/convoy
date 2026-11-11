import SwiftUI
import ConvoyDomain

// MARK: - Ventana principal (852 × 712, dos columnas)

struct MainView: View {
    @Bindable var model: AppModel
    var close: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            Divider().overlay(Tokens.border)
            HStack(spacing: 0) {
                Group {
                    switch model.tab {
                    case .newProject: NewProjectView(model: model)
                    case .templates: TemplatesView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider().overlay(Tokens.border)
                PreviewTreeView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Tokens.surface)
            }
        }
        .frame(width: 852, height: 712)
        .background(Tokens.background)
        .background(shortcuts)
    }

    /// Atajos de la guía: ⌘1 y ⌘2 cambian de pestaña; Esc y ⌘W cierran la ventana.
    private var shortcuts: some View {
        ZStack {
            Button("") { model.tab = .newProject }.keyboardShortcut("1", modifiers: .command)
            Button("") { model.tab = .templates }.keyboardShortcut("2", modifiers: .command)
            Button("") { close() }.keyboardShortcut(.cancelAction)
            Button("") { close() }.keyboardShortcut("w", modifiers: .command)
        }
        .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct TopBar: View {
    @Bindable var model: AppModel
    var body: some View {
        HStack {
            if let logo = BrandImage.logo {
                Image(nsImage: logo).renderingMode(.template).resizable().scaledToFit().frame(height: 24)
                    .foregroundStyle(Tokens.ink).accessibilityLabel("Convoy")
            } else {
                Text("convoy").font(.system(size: 18, weight: .bold))
            }
            Spacer()
            Segmented(options: [(.newProject, L("Nuevo proyecto")), (.templates, L("Plantillas"))], selection: $model.tab)
        }
        .padding(.horizontal, 20).frame(height: 56)
    }
}

enum BrandImage {
    static func template(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"), let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        return img
    }
    static var logo: NSImage? { template("Logo") }
    static var symbol: NSImage? { template("Symbol") }
}

// MARK: - Pestaña «Nuevo proyecto»

struct NewProjectView: View {
    @Bindable var model: AppModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Nombre del proyecto")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
                FieldBox {
                    TextField("", text: $model.projectName, prompt: Text(L("Expansión Perú")).foregroundStyle(Tokens.inkTertiary.opacity(0.6)))
                        .textFieldStyle(.plain).font(.system(size: 14))
                        .focused($nameFocused)
                        .accessibilityLabel(L("Nombre del proyecto"))
                        .onSubmit { Task { await model.create() } }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Plantilla")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
                VStack(spacing: 8) {
                    ForEach(model.templates) { t in TemplateRow(template: t, selected: t.id == model.selectedTemplateID) { model.selectedTemplateID = t.id } }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Crear en")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
                DestinationMenu(model: model)
            }
            Toggle(L("Incluir el nombre del proyecto en cada carpeta"), isOn: $model.includeName)
                .toggleStyle(.checkbox).font(.system(size: 13))
            Messages(model: model)
            Spacer(minLength: 0)
            Footer(model: model)
        }
        .padding(20)
        .onAppear { nameFocused = true }
        .onChange(of: model.focusTick) { nameFocused = true }
    }
}

struct TemplateRow: View {
    let template: Template
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(template.name).font(.system(size: 14, weight: selected ? .semibold : .regular)).foregroundStyle(Tokens.ink)
                Spacer()
                Text(L("%d carpetas", template.folderCount)).font(.system(size: 12)).foregroundStyle(Tokens.inkTertiary)
            }
            .padding(.horizontal, 12).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(selected ? Tokens.surfaceSelected : Tokens.background))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card).strokeBorder(selected ? Tokens.ink : Tokens.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct DestinationMenu: View {
    @Bindable var model: AppModel
    var body: some View {
        Menu {
            Button { model.setDestination(model.defaultDestination) } label: {
                Label("\(breadcrumb(model.defaultDestination))  (\(L("predeterminada")))",
                      systemImage: model.destination == model.defaultDestination ? "checkmark" : "star")
            }
            if !model.recents.isEmpty {
                Divider()
                ForEach(model.recents, id: \.self) { url in
                    Button { model.setDestination(url) } label: {
                        Label(breadcrumb(url), systemImage: model.destination.standardizedFileURL == url.standardizedFileURL ? "checkmark" : "clock")
                    }
                }
            }
            Divider()
            Button(L("Otra carpeta…")) { model.chooseOtherFolder() }
            if model.destination.standardizedFileURL != model.defaultDestination.standardizedFileURL {
                Button(L("Usar esta carpeta como predeterminada")) { model.makeDestinationDefault() }
            }
        } label: {
            HStack {
                Text(breadcrumb(model.destination)).font(.system(size: 14)).foregroundStyle(Tokens.ink).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
            }
            .padding(.horizontal, 12).frame(minHeight: Tokens.minControlHeight)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.field).fill(Tokens.background))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.field).strokeBorder(Tokens.borderControl, lineWidth: 1))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
        .accessibilityLabel(L("Crear en"))
    }
}

/// Avisos y errores: texto de advertencia de la guía (#8A4B00).
struct Messages: View {
    @Bindable var model: AppModel
    var body: some View {
        let lines = [model.message].compactMap { $0 } + (model.message == nil ? model.warnings : [])
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { Text($0).font(.system(size: 12)).foregroundStyle(Tokens.warning).fixedSize(horizontal: false, vertical: true) }
            if model.existingURL != nil {
                Button(L("Mostrar en Finder")) { model.revealExisting() }.buttonStyle(.secondary).frame(maxWidth: 220)
            }
        }
    }
}

struct Footer: View {
    @Bindable var model: AppModel
    var body: some View {
        switch model.phase {
        case .editing:
            Button { Task { await model.create() } } label: {
                Text(L("Crear proyecto · %d carpetas", folderCount))
            }
            .buttonStyle(.primary).disabled(!model.canCreate)
            .keyboardShortcut(.defaultAction)
        case .created(_, let count, let where_):
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Proyecto creado")).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tokens.ink)
                    Text(L("%d carpetas en %@", count, where_)).font(.system(size: 13)).foregroundStyle(Tokens.inkSecondary)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(Tokens.surfaceStatus))
                .accessibilityElement(children: .combine)
                Button(L("Mostrar en Finder")) { model.revealCreated() }.buttonStyle(.primary).keyboardShortcut(.defaultAction)
                Button(L("Crear otro")) { model.startAnother() }.buttonStyle(.secondary)
            }
        }
    }

    private var folderCount: Int { if case .success(let p) = model.planResult { return p.folderCount } else { return model.selectedTemplate?.folderCount ?? 0 } }
}

// MARK: - Vista previa del árbol

struct PreviewTreeView: View {
    var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(L("Vista previa"))
                Spacer()
                Text(breadcrumb(model.destination)).font(.system(size: 12)).foregroundStyle(Tokens.inkTertiary).lineLimit(1)
            }
            switch model.planResult {
            case .success(let plan):
                ScrollView { tree(plan).frame(maxWidth: .infinity, alignment: .leading) }
                Text(L("Ruta más larga: %d caracteres · límite seguro para Windows: %d", plan.longestPathLength, PathBudget.warnAbove))
                    .font(.system(size: 11)).foregroundStyle(PathBudget.shouldWarn(plan.longestPathLength) ? Tokens.warning : Tokens.inkTertiary)
            case .failure(let error):
                Text(error.localizedDescription).font(.system(size: 13)).foregroundStyle(Tokens.warning)
                Spacer()
            }
        }
        .padding(20)
        .accessibilityElement(children: .contain)
    }

    private func tree(_ plan: CreationPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder").font(.system(size: 14))
                Text(plan.rootName).font(.system(size: 14, weight: .semibold)).opacity(model.isPlaceholder ? 0.55 : 1)
            }
            .foregroundStyle(Tokens.ink)
            ForEach(Array(plan.folders.enumerated()), id: \.offset) { _, folder in
                HStack(spacing: 8) {
                    Image(systemName: "folder").font(.system(size: folder.depth == 1 ? 12 : 11))
                    Text(folder.name).font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(folder.depth == 1 ? Tokens.ink : Tokens.inkSecondary)
                .padding(.leading, 22 + CGFloat(folder.depth - 1) * 20)
            }
        }
    }
}

import SwiftUI
import ConvoyDomain

// MARK: - Pestaña «Plantillas»

struct TemplatesView: View {
    @Bindable var model: AppModel
    @State private var newFolder = ""
    @State private var confirmDelete = false

    var body: some View {
        let template = model.selectedTemplate
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Editar plantilla")).font(.system(size: 16, weight: .bold)).foregroundStyle(Tokens.ink)
                    Text(L("Los cambios se guardan solos y se ven a la derecha.")).font(.system(size: 12)).foregroundStyle(Tokens.inkTertiary)
                }
                Spacer()
                menu(template)
            }
            pills
            if let template {
                if template.isBuiltIn {
                    HStack {
                        Text(L("Las plantillas de fábrica no se pueden cambiar. Duplícala para editarla.")).font(.system(size: 12)).foregroundStyle(Tokens.inkSecondary)
                        Spacer()
                        Button(L("Duplicar")) { model.duplicateSelected() }.buttonStyle(.secondary).frame(width: 110)
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(Tokens.surfaceStatus))
                } else {
                    FieldBox {
                        TextField(L("Nombre de la plantilla"), text: Binding(get: { template.name }, set: { n in model.edit { $0.name = n } }))
                            .textFieldStyle(.plain).font(.system(size: 14, weight: .semibold))
                    }
                }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(template.folders.enumerated()), id: \.element.id) { index, node in
                            FolderRow(model: model, node: node, number: String(format: "%02d", index + 1), isFirst: index == 0, isLast: index == template.folders.count - 1,
                                      editable: !template.isBuiltIn, indent: false)
                            ForEach(Array(node.children.enumerated()), id: \.element.id) { j, child in
                                FolderRow(model: model, node: child, number: "", isFirst: j == 0, isLast: j == node.children.count - 1, editable: !template.isBuiltIn, indent: true)
                            }
                            if !template.isBuiltIn {
                                Button(L("+ Subcarpeta")) { model.edit { $0.addSubfolder(named: L("Subcarpeta"), to: node.id) } }
                                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 62)
                            }
                        }
                    }
                }
                if !template.isBuiltIn {
                    HStack(spacing: 8) {
                        FieldBox {
                            TextField("", text: $newFolder, prompt: Text(L("Nueva carpeta, ej.: Riesgos")).foregroundStyle(Tokens.inkTertiary.opacity(0.6)))
                                .textFieldStyle(.plain).font(.system(size: 13)).onSubmit(add)
                        }
                        Button(L("Agregar"), action: add).buttonStyle(.primary).frame(width: 96)
                            .disabled(newFolder.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            if let message = model.message { Text(message).font(.system(size: 12)).foregroundStyle(Tokens.warning) }
            Spacer(minLength: 0)
        }
        .padding(20)
        .confirmationDialog(L("¿Eliminar la plantilla?"), isPresented: $confirmDelete) {
            Button(L("Eliminar"), role: .destructive) { model.deleteSelected() }
            Button(L("Cancelar"), role: .cancel) {}
        } message: { Text(L("Se borra solo la plantilla, no las carpetas de tus proyectos.")) }
    }

    private func add() {
        let name = newFolder
        model.edit { $0.addFolder(named: name) }
        newFolder = ""
    }

    private var pills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.templates) { t in
                    Button { model.selectedTemplateID = t.id } label: {
                        Text(t.name).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(t.id == model.selectedTemplateID ? Tokens.background : Tokens.ink)
                            .padding(.horizontal, 14).frame(height: 30)
                            .background(Capsule().fill(t.id == model.selectedTemplateID ? Tokens.ink : Tokens.background))
                            .overlay(Capsule().strokeBorder(Tokens.borderControl, lineWidth: t.id == model.selectedTemplateID ? 0 : 1))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(t.id == model.selectedTemplateID ? .isSelected : [])
                }
                Button { model.duplicateSelected() } label: {
                    Text(L("+ Duplicar como nueva")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Tokens.ink)
                        .padding(.horizontal, 14).frame(height: 30)
                        .overlay(Capsule().strokeBorder(Tokens.borderControl, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }.buttonStyle(.plain)
            }
        }
    }

    private func menu(_ template: Template?) -> some View {
        Menu {
            Button(L("Nueva plantilla")) { model.newTemplate() }
            Button(L("Importar…")) { model.chooseImportFile() }
            Button(L("Exportar…")) { model.chooseExportFile() }.disabled(template == nil)
            Divider()
            Button(L("Eliminar plantilla…"), role: .destructive) { confirmDelete = true }.disabled(template == nil || template?.isBuiltIn == true)
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tokens.ink).frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.icon).fill(Tokens.background))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.icon).strokeBorder(Tokens.borderControl, lineWidth: 1))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().accessibilityLabel(L("Más acciones"))
    }
}

struct FolderRow: View {
    var model: AppModel
    let node: FolderNode
    let number: String
    let isFirst: Bool
    let isLast: Bool
    let editable: Bool
    let indent: Bool

    var body: some View {
        HStack(spacing: 8) {
            if !indent { Text(number).font(.system(size: 12, design: .monospaced)).foregroundStyle(Tokens.inkTertiary).frame(width: 22, alignment: .leading) }
            TextField("", text: Binding(get: { node.name }, set: { n in model.edit { $0.rename(folder: node.id, to: n) } }))
                .textFieldStyle(.plain).font(.system(size: 13)).disabled(!editable)
                .accessibilityLabel(L("Nombre de la carpeta"))
            if editable {
                Button { model.edit { $0.move(folder: node.id, by: -1) } } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.icon).disabled(isFirst).accessibilityLabel(L("Subir"))
                Button { model.edit { $0.move(folder: node.id, by: 1) } } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.icon).disabled(isLast).accessibilityLabel(L("Bajar"))
                Button { model.edit { $0.remove(folder: node.id) } } label: { Image(systemName: "xmark") }
                    .buttonStyle(.icon).accessibilityLabel(L("Quitar"))
            }
        }
        .padding(.horizontal, 10).frame(minHeight: indent ? 38 : 42)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.field).fill(Tokens.background))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.field).strokeBorder(Tokens.border, lineWidth: 1))
        .padding(.leading, indent ? 40 : 0)
    }
}

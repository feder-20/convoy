import SwiftUI
import ConvoyLicensing

/// Línea permanente y discreta al pie de la vista previa: «Versión de prueba · quedan N días · Premium: 10 USD».
struct TrialBanner: View {
    var trial: TrialController
    var body: some View {
        if let text = TrialTexts.banner(trial.state) {
            let urgent: Bool = { if case .lastDays = trial.state { return true } else { return false } }()
            VStack(alignment: .leading, spacing: 4) {
                Divider().overlay(Tokens.border)
                Text(text).font(.system(size: 11, weight: urgent ? .semibold : .regular))
                    .foregroundStyle(urgent ? Tokens.warning : Tokens.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Obtener premium")) { trial.openPurchase() }
                    .buttonStyle(.link).font(.system(size: 11))
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// Ventana de activación. Con la prueba vencida no se cierra con Esc: solo se activa la clave o se sale.
struct ActivationView: View {
    var trial: TrialController
    var expired: Bool
    var close: () -> Void
    var quit: () -> Void
    @State private var key = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(expired ? L("El periodo de prueba terminó") : L("Introducir clave")).font(.system(size: 20, weight: .bold))
            Text(expired ? L("Gracias por probar Convoy. Para seguir usándola, obtén la versión premium (10 USD, pago único). Tus plantillas y tus carpetas siguen intactas.")
                         : L("Pega aquí la clave de la versión premium que recibiste."))
                .font(.system(size: 13)).foregroundStyle(Tokens.inkSecondary).fixedSize(horizontal: false, vertical: true)
            if expired { Button(L("Obtener premium")) { trial.openPurchase() }.buttonStyle(.primary) }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Tengo una clave")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.inkSecondary)
                FieldBox {
                    TextField("", text: $key, prompt: Text(L("Pega la clave aquí")).foregroundStyle(Tokens.inkTertiary.opacity(0.6)))
                        .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                        .accessibilityLabel(L("Tengo una clave"))
                        .onSubmit(activate)
                }
                if let error { Text(error).font(.system(size: 12)).foregroundStyle(Tokens.warning) }
            }
            HStack {
                Button(L("Activar"), action: activate).buttonStyle(.secondary)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                if expired { Button(L("Salir"), action: quit).buttonStyle(.secondary) }
                else { Button(L("Cerrar"), action: close).buttonStyle(.secondary).keyboardShortcut(.cancelAction) }
            }
        }
        .padding(24).frame(width: 460)
        .background(Tokens.background)
    }

    private func activate() {
        if let e = trial.activate(key) { error = e } else { key = ""; error = nil; close() }
    }
}

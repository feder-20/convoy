import SwiftUI
import AppKit

/// Tokens de `guia-visual/design-tokens.json`. En modo claro, los valores de la guía; en oscuro, colores semánticos del sistema.
enum Tokens {
    private static func dynamic(light: Int, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : hex(light)
        })
    }
    private static func hex(_ v: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    static let ink = dynamic(light: 0x111111, dark: .labelColor)
    static let inkSecondary = dynamic(light: 0x4A4A4A, dark: .secondaryLabelColor)
    static let inkTertiary = dynamic(light: 0x5C5C5C, dark: .secondaryLabelColor)
    static let border = dynamic(light: 0xE6E6E6, dark: .separatorColor)
    static let borderControl = dynamic(light: 0xCFCFCF, dark: .separatorColor)
    static let surface = dynamic(light: 0xFAFAFA, dark: .controlBackgroundColor)
    static let surfaceSelected = dynamic(light: 0xF4F4F4, dark: NSColor.labelColor.withAlphaComponent(0.08))
    static let surfaceStatus = dynamic(light: 0xF2F2F2, dark: NSColor.labelColor.withAlphaComponent(0.06))
    static let segmentedTrack = dynamic(light: 0xEBEBEB, dark: NSColor.labelColor.withAlphaComponent(0.10))
    static let background = dynamic(light: 0xFFFFFF, dark: .windowBackgroundColor)
    static let warning = dynamic(light: 0x8A4B00, dark: .systemOrange)

    enum Radius { static let icon: CGFloat = 7, field: CGFloat = 9, button: CGFloat = 10, card: CGFloat = 10, window: CGFloat = 14 }
    static let minControlHeight: CGFloat = 44
    static let disabledOpacity = 0.35
}

/// Botón primario: negro con texto blanco (invertido en oscuro). Altura mínima 44, deshabilitado al 35 %.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Tokens.background)
            .frame(maxWidth: .infinity, minHeight: Tokens.minControlHeight)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.button).fill(Tokens.ink.opacity(configuration.isPressed ? 0.85 : 1)))
            .opacity(isEnabled ? 1 : Tokens.disabledOpacity)
    }
}

/// Botón secundario: fondo del tema, borde de control.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Tokens.ink)
            .frame(maxWidth: .infinity, minHeight: Tokens.minControlHeight)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.button).fill(configuration.isPressed ? Tokens.surfaceSelected : Tokens.background))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.button).strokeBorder(Tokens.borderControl, lineWidth: 1))
            .opacity(isEnabled ? 1 : Tokens.disabledOpacity)
    }
}

/// Botón cuadrado de 30 pt para subir, bajar y quitar.
struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Tokens.ink)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.icon).fill(configuration.isPressed ? Tokens.surfaceSelected : Tokens.background))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.icon).strokeBorder(Tokens.borderControl, lineWidth: 1))
            .opacity(isEnabled ? 1 : Tokens.disabledOpacity)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: PrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: SecondaryButtonStyle { .init() } }
extension ButtonStyle where Self == IconButtonStyle { static var icon: IconButtonStyle { .init() } }

/// Campo de texto con el borde y el radio de la guía.
struct FieldBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 12)
            .frame(minHeight: Tokens.minControlHeight)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.field).fill(Tokens.background))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.field).strokeBorder(Tokens.borderControl, lineWidth: 1))
    }
}

/// Etiqueta de sección: 11 pt, 600, mayúsculas, tracking.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.66).foregroundStyle(Tokens.inkTertiary)
    }
}

/// Control segmentado «Nuevo proyecto | Plantillas».
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button { selection = option.0 } label: {
                    Text(option.1)
                        .font(.system(size: 13, weight: selection == option.0 ? .semibold : .regular))
                        .foregroundStyle(selection == option.0 ? Tokens.ink : Tokens.inkSecondary)
                        .padding(.horizontal, 14).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selection == option.0 ? Tokens.background : .clear)
                            .shadow(color: .black.opacity(selection == option.0 ? 0.08 : 0), radius: 1.5, y: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Tokens.segmentedTrack))
    }
}

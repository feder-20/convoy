import Foundation
import ConvoyDomain

/// Textos de la prueba y la licencia (español como clave; inglés en `en.lproj`).
public enum TrialTexts {
    public static func banner(_ state: TrialState) -> String? {
        switch state {
        case .licensed, .expired: return nil
        case .trial(let d): return tr("Versión de prueba · quedan %d días · Premium: %@", d, LicenseConstants.priceText)
        case .lastDays(let d):
            return d == 1 ? tr("Último día de prueba · Premium: %@", LicenseConstants.priceText)
                          : tr("Quedan %d días de prueba · Premium: %@", d, LicenseConstants.priceText)
        }
    }

    /// Línea informativa del menú del ícono.
    public static func menuLine(_ state: TrialState, buyer: String?) -> String {
        switch state {
        case .licensed: return tr("Premium activado · %@", buyer ?? "")
        case .expired: return tr("Periodo de prueba terminado")
        default: return banner(state) ?? ""
        }
    }

    public static var welcomeTitle: String { tr("Estás usando una versión de prueba (tester)") }
    public static var welcomeBody: String {
        tr("Convoy está en periodo de prueba hasta el 9 de febrero de 2027. Es gratis durante este periodo y nos ayudas a mejorarla. Después, cada app costará 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.")
    }
    public static func reminderBody(daysLeft: Int) -> String {
        daysLeft == 1 ? tr("Hoy es el último día del periodo de prueba de Convoy. Después, la versión premium cuesta 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.")
                      : tr("Quedan %d días del periodo de prueba de Convoy. Después, la versión premium cuesta 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.", daysLeft)
    }

    public static func message(for error: LicenseError) -> String {
        switch error {
        case .invalid: return tr("La clave no es válida. Revisa que esté completa.")
        case .wrongApp: return tr("Esa clave es de otra app.")
        case .alreadyActive: return tr("Esa clave ya está activada.")
        }
    }
}

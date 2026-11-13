import Foundation
import ConvoyDomain

/// Textos de la prueba y la licencia (español como clave; inglés en `en.lproj`).
public enum TrialTexts {
    public static func banner(_ state: TrialState) -> String? {
        switch state {
        case .licensed, .expired: return nil
        case .trial(let d): return tr("Versión de prueba · quedan %d días de %d · Premium: %@", d, LicenseConstants.trialDays, LicenseConstants.priceText)
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
    /// Fecha larga con la región del usuario (el calendario trae la zona horaria).
    public static func formatDate(_ date: Date, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }

    public static func welcomeBody(endDate: String) -> String {
        tr("Convoy está en periodo de prueba: úsala gratis durante 90 días (hasta el %@) y ayúdanos a mejorarla. Después, cada app costará 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.", endDate)
    }
    public static func reminderBody(daysLeft: Int, endDate: String) -> String {
        daysLeft == 1 ? tr("Hoy es el último día del periodo de prueba de Convoy (hasta el %@). Después, la versión premium cuesta 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.", endDate)
                      : tr("Quedan %d días del periodo de prueba de Convoy (hasta el %@). Después, la versión premium cuesta 10 USD (pago único). Tus archivos nunca se tocan ni se pierden.", daysLeft, endDate)
    }
    public static func endLine(endDate: String) -> String { tr("La prueba de 90 días termina el %@", endDate) }

    public static func message(for error: LicenseError) -> String {
        switch error {
        case .invalid: return tr("La clave no es válida. Revisa que esté completa.")
        case .wrongApp: return tr("Esa clave es de otra app.")
        case .alreadyActive: return tr("Esa clave ya está activada.")
        }
    }
}

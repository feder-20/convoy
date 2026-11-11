import Foundation

/// Constantes comunes de la prueba y la licencia (ChocolitosLicense/SPEC.md).
public enum LicenseConstants {
    public static let appID = "convoy"
    public static let priceText = "10 USD"
    /// Única constante de la página de compra: es lo único que la app abre en el navegador.
    public static let purchaseURL = URL(string: "https://chocolitossoft.com/premium")!
    /// Fin de la prueba: 9 de febrero de 2027, 23:59:59 (hora local del usuario).
    public static let trialEndComponents = DateComponents(year: 2027, month: 2, day: 9, hour: 23, minute: 59, second: 59)
    /// Clave pública ECDSA P-256 (SPKI DER en base64).
    public static let publicKeyDER = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAErtZHvwOjaMNN6Wv5ts90ulpylP9W1Y9Q7ChUIEvUlSZs7Tjvf+ZvGKoVDkE6Xl/LRx5k67YzxqilIIAE/c2GXQ=="
}

public enum TrialState: Equatable, Sendable {
    case licensed
    case trial(daysLeft: Int)
    /// Quedan 14 días o menos.
    case lastDays(daysLeft: Int)
    case expired
}

/// Único punto de verdad del estado de la prueba. Recibe el reloj y la última fecha vista como parámetros.
public enum TrialPolicy {
    public static let lastDaysThreshold = 14

    public static func trialEnd(calendar: Calendar = .current) -> Date {
        calendar.date(from: LicenseConstants.trialEndComponents)!
    }

    /// Días de calendario completos hasta el fin de la prueba: el 9 de febrero devuelve 1 («último día»); el 10, 0 o menos.
    public static func daysLeft(now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let firstExpiredDay = calendar.date(from: DateComponents(year: 2027, month: 2, day: 10))!
        return calendar.dateComponents([.day], from: today, to: firstExpiredDay).day ?? 0
    }

    /// `effectiveNow = max(now, lastSeen)`: retrasar el reloj no revive la prueba. Una licencia válida gana siempre.
    public static func state(now: Date, lastSeen: Date?, licensed: Bool, calendar: Calendar = .current) -> TrialState {
        if licensed { return .licensed }
        let effective = max(now, lastSeen ?? now)
        let days = daysLeft(now: effective, calendar: calendar)
        if days <= 0 { return .expired }
        return days <= lastDaysThreshold ? .lastDays(daysLeft: days) : .trial(daysLeft: days)
    }
}

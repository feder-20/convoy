import Foundation

/// Constantes comunes de la prueba y la licencia (ChocolitosLicense/SPEC.md).
public enum LicenseConstants {
    public static let appID = "convoy"
    public static let priceText = "10 USD"
    /// Única constante de la página de compra: es lo único que la app abre en el navegador.
    public static let purchaseURL = URL(string: "https://chocolitossoft.com/premium")!
    /// La prueba dura 90 días por persona, contados desde la primera vez que abre la app.
    public static let trialDays = 90
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

    /// Primer día ya vencido (00:00 local): D0 + 90 días de calendario, con D0 = día local de `firstLaunch`.
    public static func expiryDay(firstLaunch: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: LicenseConstants.trialDays, to: calendar.startOfDay(for: firstLaunch))!
    }

    /// Último día de la prueba (D0 + 89, 00:00 local): el que se muestra como «hasta el <fecha>».
    public static func endDate(firstLaunch: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: expiryDay(firstLaunch: firstLaunch, calendar: calendar))!
    }

    /// Días de calendario hasta `expiryDay`: el día D0 devuelve 90; D0+89, 1 («último día»); D0+90 en adelante, 0 o menos.
    public static func daysLeft(now: Date, firstLaunch: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: today, to: expiryDay(firstLaunch: firstLaunch, calendar: calendar)).day ?? 0
    }

    /// `effectiveNow = max(now, lastSeen)`: retrasar el reloj no revive la prueba. Un `firstLaunch` en el futuro
    /// (manipulado) se trata como `effectiveNow`. Una licencia válida gana siempre.
    public static func state(now: Date, firstLaunch: Date, lastSeen: Date?, licensed: Bool, calendar: Calendar = .current) -> TrialState {
        if licensed { return .licensed }
        let effective = max(now, lastSeen ?? now)
        let days = daysLeft(now: effective, firstLaunch: min(firstLaunch, effective), calendar: calendar)
        if days <= 0 { return .expired }
        return days <= lastDaysThreshold ? .lastDays(daysLeft: days) : .trial(daysLeft: days)
    }
}

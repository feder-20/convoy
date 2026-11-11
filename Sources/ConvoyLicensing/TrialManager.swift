import Foundation
import ConvoyDomain
import ConvoyPorts

/// Almacén de preferencias abstracto (UserDefaults en producción, memoria en pruebas).
public protocol KeyValueStore: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}

public final class MemoryStore: KeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]
    public init() {}
    public func string(forKey key: String) -> String? { lock.withLock { values[key] } }
    public func set(_ value: String?, forKey key: String) { lock.withLock { values[key] = value } }
}

public final class UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults
    public init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    public func set(_ value: String?, forKey key: String) { defaults.set(value, forKey: key) }
}

/// Estado de la prueba y la licencia: reloj, calendario, almacén y clave pública se inyectan.
public final class TrialManager: @unchecked Sendable {
    enum Key {
        static let license = "convoy.trial.licenseKey"
        static let lastSeen = "convoy.trial.lastSeen"
        static let welcomeSeen = "convoy.trial.welcomeSeen"
        static let lastReminderDay = "convoy.trial.lastReminderDay"
    }

    private let app: String
    private let publicKeyDER: String
    private let store: KeyValueStore
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let lock = NSLock()

    public init(app: String = LicenseConstants.appID, publicKeyDER: String = LicenseConstants.publicKeyDER, store: KeyValueStore,
                now: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .autoupdatingCurrent) {
        self.app = app
        self.publicKeyDER = publicKeyDER
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    /// La licencia guardada se vuelve a verificar cada vez; una licencia nunca se desactiva por fecha.
    public var license: LicensePayload? {
        guard let key = store.string(forKey: Key.license) else { return nil }
        return try? LicenseVerifier.verify(key, app: app, publicKeyDER: publicKeyDER)
    }

    private var lastSeen: Date? { store.string(forKey: Key.lastSeen).flatMap(Double.init).map { Date(timeIntervalSince1970: $0) } }

    public var state: TrialState { lock.withLock { currentState() } }

    /// Sin bloqueo: quien llama ya tiene el cerrojo. Guarda la fecha más alta vista (freno contra el reloj hacia atrás).
    private func currentState() -> TrialState {
        let current = now()
        let seen = lastSeen
        if seen == nil || current > seen! { store.set(String(current.timeIntervalSince1970), forKey: Key.lastSeen) }
        return TrialPolicy.state(now: current, lastSeen: seen, licensed: license != nil, calendar: calendar)
    }

    @discardableResult
    public func activate(_ raw: String) throws -> LicensePayload {
        let key = LicenseVerifier.clean(raw)
        let payload = try LicenseVerifier.verify(key, app: app, publicKeyDER: publicKeyDER)
        if store.string(forKey: Key.license) == key { throw LicenseError.alreadyActive }
        store.set(key, forKey: Key.license)
        return payload
    }

    public func removeLicense() { store.set(nil, forKey: Key.license) }

    public var welcomeSeen: Bool { store.string(forKey: Key.welcomeSeen) == "1" }
    public func markWelcomeSeen() { store.set("1", forKey: Key.welcomeSeen) }

    private var todayKey: String {
        let c = calendar.dateComponents([.year, .month, .day], from: max(now(), lastSeen ?? now()))
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// En los últimos 14 días devuelve los días restantes una sola vez por día de calendario; si no, nil.
    public func takeDailyReminder() -> Int? {
        lock.withLock {
            guard case .lastDays(let days) = currentState() else { return nil }
            guard store.string(forKey: Key.lastReminderDay) != todayKey else { return nil }
            store.set(todayKey, forKey: Key.lastReminderDay)
            return days
        }
    }
}

/// Puerta de ejecución: solo `expired` bloquea la función principal.
public struct LicenseGate: ExecutionGate {
    private let manager: TrialManager
    public init(manager: TrialManager) { self.manager = manager }
    public func check() throws {
        if manager.state == .expired { throw ConvoyError.trialExpired }
    }
}

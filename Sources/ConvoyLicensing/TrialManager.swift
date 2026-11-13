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

/// Archivo JSON pequeño (un diccionario de textos) en Application Support: segundo lugar, independiente de las preferencias.
public final class FileKeyValueStore: KeyValueStore, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    public init(url: URL) { self.url = url }

    /// `~/Library/Application Support/Convoy/prueba.json`
    public static func standard() -> FileKeyValueStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileKeyValueStore(url: base.appendingPathComponent("Convoy", isDirectory: true).appendingPathComponent("prueba.json"))
    }

    private func read() -> [String: String] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
    public func string(forKey key: String) -> String? { lock.withLock { read()[key] } }
    public func set(_ value: String?, forKey key: String) {
        lock.withLock {
            var d = read()
            d[key] = value
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(d).write(to: url, options: .atomic)
            } catch { /* sin el archivo, queda el valor de las preferencias */ }
        }
    }
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
        static let firstLaunch = "convoy.trial.firstLaunch"
        static let lastSeen = "convoy.trial.lastSeen"
        static let welcomeSeen = "convoy.trial.welcomeSeen"
        static let lastReminderDay = "convoy.trial.lastReminderDay"
    }

    private let app: String
    private let publicKeyDER: String
    private let store: KeyValueStore
    /// Segundo registro de `firstLaunch` (archivo en Application Support en producción).
    private let backup: KeyValueStore
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let lock = NSLock()

    public init(app: String = LicenseConstants.appID, publicKeyDER: String = LicenseConstants.publicKeyDER, store: KeyValueStore,
                backup: KeyValueStore = MemoryStore(), now: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .autoupdatingCurrent) {
        self.app = app
        self.publicKeyDER = publicKeyDER
        self.store = store
        self.backup = backup
        self.now = now
        self.calendar = calendar
        // El primer uso se registra al crear el gestor (arranque de la app), no la primera vez que alguien pregunta el estado.
        _ = self.state
    }

    /// La licencia guardada se vuelve a verificar cada vez; una licencia nunca se desactiva por fecha.
    public var license: LicensePayload? {
        guard let key = store.string(forKey: Key.license) else { return nil }
        return try? LicenseVerifier.verify(key, app: app, publicKeyDER: publicKeyDER)
    }

    private var lastSeen: Date? { store.string(forKey: Key.lastSeen).flatMap(Double.init).map { Date(timeIntervalSince1970: $0) } }

    public static let firstLaunchKey = Key.firstLaunch

    private func stored(_ s: KeyValueStore) -> Date? { s.string(forKey: Key.firstLaunch).flatMap(Double.init).map { Date(timeIntervalSince1970: $0) } }

    /// Primer uso: se guarda en dos lugares independientes y se usa el más antiguo; si falta uno se recrea desde el otro.
    /// Sin ninguno (instalación nueva o migración desde 0.2.0, de fecha fija) empieza ahora: 90 días completos.
    /// Un valor en el futuro (manipulado) se reemplaza por `effectiveNow`. Sin bloqueo: quien llama ya tiene el cerrojo.
    private func resolveFirstLaunch(effectiveNow: Date) -> Date {
        let found = [stored(store), stored(backup)].compactMap { $0 }
        var first = found.min() ?? effectiveNow
        if first > effectiveNow { first = effectiveNow }
        let text = String(first.timeIntervalSince1970)
        for s in [store, backup] where stored(s) != first { s.set(text, forKey: Key.firstLaunch) }
        return first
    }

    public var firstLaunch: Date { lock.withLock { resolveFirstLaunch(effectiveNow: effectiveNow()) } }

    /// Último día de la prueba para esta persona (para «hasta el <fecha>»).
    public var endDate: Date { TrialPolicy.endDate(firstLaunch: firstLaunch, calendar: calendar) }

    private func effectiveNow() -> Date { max(now(), lastSeen ?? now()) }

    public var state: TrialState { lock.withLock { currentState() } }

    /// Sin bloqueo: quien llama ya tiene el cerrojo. Guarda la fecha más alta vista (freno contra el reloj hacia atrás).
    private func currentState() -> TrialState {
        let current = now()
        let seen = lastSeen
        if seen == nil || current > seen! { store.set(String(current.timeIntervalSince1970), forKey: Key.lastSeen) }
        let first = resolveFirstLaunch(effectiveNow: max(current, seen ?? current))
        return TrialPolicy.state(now: current, firstLaunch: first, lastSeen: seen, licensed: license != nil, calendar: calendar)
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

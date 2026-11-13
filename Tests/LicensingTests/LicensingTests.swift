import XCTest
import CryptoKit
import ConvoyDomain
import ConvoyPorts
import ConvoyLicensing

enum LicenseFixtures {
    static let priv = P256.Signing.PrivateKey()
    static var publicDER: String { priv.publicKey.derRepresentation.base64EncodedString() }

    static func b64url(_ d: Data, pad: Bool = false) -> String {
        var s = d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        if !pad { while s.hasSuffix("=") { s.removeLast() } }
        return s
    }
    static func key(app: String = "convoy", prefix: String? = nil, name: String = "Prueba", signer: P256.Signing.PrivateKey = priv, pad: Bool = false) -> String {
        let payload = Data(#"{"app":"\#(app)","name":"\#(name)","issued":"2026-11-11T00:00:00Z"}"#.utf8)
        let sig = try! signer.signature(for: payload).rawRepresentation
        return "\(prefix ?? app.uppercased()).\(b64url(payload, pad: pad)).\(b64url(sig, pad: pad))"
    }
}

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ sec: Int = 0, tz: String? = nil) -> (Date, Calendar) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: tz ?? "America/Bogota")!
    return (cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: sec))!, cal)
}

final class TrialPolicyTests: XCTestCase {
    /// firstLaunch fijo: 11 nov 2026 a las 12:00 (D0). `day(k)` = D0 + k días de calendario.
    func cal(_ tz: String? = nil) -> Calendar { at(2026, 11, 11, tz: tz).1 }
    func first(_ tz: String? = nil) -> Date { at(2026, 11, 11, 12, tz: tz).0 }
    func day(_ k: Int, _ h: Int = 12, _ m: Int = 0, _ s: Int = 0, tz: String? = nil) -> Date {
        let c = cal(tz)
        let start = c.startOfDay(for: first(tz))
        let d = c.date(byAdding: .day, value: k, to: start)!
        return c.date(bySettingHour: h, minute: m, second: s, of: d)!
    }
    func state(_ now: Date, first f: Date? = nil, lastSeen: Date? = nil, licensed: Bool = false, tz: String? = nil) -> TrialState {
        TrialPolicy.state(now: now, firstLaunch: f ?? first(tz), lastSeen: lastSeen, licensed: licensed, calendar: cal(tz))
    }

    func testConstants() { XCTAssertEqual(LicenseConstants.trialDays, 90) }

    func testStatesAndBoundaries() {
        XCTAssertEqual(state(day(0, 12)), .trial(daysLeft: 90), "el día del primer uso quedan 90")
        XCTAssertEqual(state(day(0, 0, 0, 0)), .trial(daysLeft: 90))
        XCTAssertEqual(state(day(1)), .trial(daysLeft: 89))
        XCTAssertEqual(state(day(74)), .trial(daysLeft: 16))
        XCTAssertEqual(state(day(75)), .trial(daysLeft: 15), "15 días: aún sin aviso destacado")
        XCTAssertEqual(state(day(76)), .lastDays(daysLeft: 14), "14 días: últimos días")
        XCTAssertEqual(state(day(88)), .lastDays(daysLeft: 2))
        XCTAssertEqual(state(day(89, 0, 0, 0)), .lastDays(daysLeft: 1), "el día 90 es el último")
        XCTAssertEqual(state(day(89, 23, 59, 59)), .lastDays(daysLeft: 1))
        XCTAssertEqual(state(day(90, 0, 0, 0)), .expired, "medianoche: el día 91 está vencido")
        XCTAssertEqual(state(day(91)), .expired)
        XCTAssertEqual(state(day(1000)), .expired)
    }

    func testEndDateIsTheLastDayAndExpiryTheNext() {
        let c = cal()
        XCTAssertEqual(TrialPolicy.endDate(firstLaunch: first(), calendar: c), day(89, 0, 0, 0))
        XCTAssertEqual(c.dateComponents([.year, .month, .day], from: TrialPolicy.endDate(firstLaunch: first(), calendar: c)),
                       DateComponents(year: 2027, month: 2, day: 8))
        XCTAssertEqual(TrialPolicy.expiryDay(firstLaunch: first(), calendar: c), day(90, 0, 0, 0))
        // No depende de la hora del primer uso.
        XCTAssertEqual(TrialPolicy.endDate(firstLaunch: day(0, 23, 59, 59), calendar: c), TrialPolicy.endDate(firstLaunch: day(0, 0, 0, 1), calendar: c))
    }

    func testClockGoingBackwardsDoesNotReviveTheTrial() {
        XCTAssertEqual(state(day(10), lastSeen: day(120)), .expired)
        XCTAssertEqual(state(day(80), lastSeen: day(10)), .lastDays(daysLeft: 10), "un lastSeen anterior no cambia nada")
    }

    func testFutureFirstLaunchIsTreatedAsNow() {
        // firstLaunch manipulado a un año en el futuro: cuenta desde «ahora», no regala tiempo.
        XCTAssertEqual(state(day(5), first: day(400)), .trial(daysLeft: 90))
        XCTAssertEqual(state(day(5), first: day(6, 0, 0, 1)), .trial(daysLeft: 90))
    }

    func testLicenseWinsOverEverything() {
        XCTAssertEqual(state(day(2000), licensed: true), .licensed)
        XCTAssertEqual(state(day(5), licensed: true), .licensed)
    }

    func testTimeZonesAndDSTDoNotShiftByADay() {
        for tz in ["America/Bogota", "America/New_York", "Europe/Madrid", "Pacific/Auckland", "Asia/Tokyo"] {
            XCTAssertEqual(state(day(89, 23, 59, 59, tz: tz), tz: tz), .lastDays(daysLeft: 1), tz)
            XCTAssertEqual(state(day(90, 0, 0, 0, tz: tz), tz: tz), .expired, tz)
            XCTAssertEqual(state(day(0, tz: tz), tz: tz), .trial(daysLeft: 90), tz)
        }
        // Cruce de horario de verano: primer uso justo antes del cambio (EE. UU. 8 mar 2026, Europa 29 mar 2026 y 25 oct 2026).
        for (tz, y, m, d) in [("America/New_York", 2026, 3, 1), ("Europe/Madrid", 2026, 3, 20), ("Europe/Madrid", 2026, 10, 15), ("America/New_York", 2026, 10, 25)] {
            let (f, c) = at(y, m, d, 23, 30, tz: tz)
            let start = c.startOfDay(for: f)
            func s(_ k: Int, _ h: Int, _ mi: Int = 0, _ sec: Int = 0) -> TrialState {
                let dd = c.date(byAdding: .day, value: k, to: start)!
                return TrialPolicy.state(now: c.date(bySettingHour: h, minute: mi, second: sec, of: dd)!, firstLaunch: f, lastSeen: nil, licensed: false, calendar: c)
            }
            XCTAssertEqual(s(0, 23, 59), .trial(daysLeft: 90), "\(tz) \(m)/\(d)")
            XCTAssertEqual(s(89, 0), .lastDays(daysLeft: 1), "\(tz) \(m)/\(d)")
            XCTAssertEqual(s(89, 23, 59, 59), .lastDays(daysLeft: 1), "\(tz) \(m)/\(d)")
            XCTAssertEqual(s(90, 0), .expired, "\(tz) \(m)/\(d)")
        }
    }
}

final class LicenseVerifierTests: XCTestCase {
    let app = "convoy"
    func verify(_ k: String, key: String = LicenseFixtures.publicDER) throws -> LicensePayload { try LicenseVerifier.verify(k, app: app, publicKeyDER: key) }
    func assertThrows(_ k: String, _ e: LicenseError, key: String = LicenseFixtures.publicDER, line: UInt = #line) {
        XCTAssertThrowsError(try verify(k, key: key), line: line) { XCTAssertEqual($0 as? LicenseError, e, line: line) }
    }

    func testValidKeyAndAllKey() throws {
        let p = try verify(LicenseFixtures.key())
        XCTAssertEqual(p.app, "convoy"); XCTAssertEqual(p.name, "Prueba")
        XCTAssertEqual(try verify(LicenseFixtures.key(app: "all")).app, "all")
    }

    func testWrongApp() {
        assertThrows(LicenseFixtures.key(app: "ferry"), .wrongApp)
        assertThrows(LicenseFixtures.key(app: "cabrio"), .wrongApp)
    }

    func testTamperedPayloadSignaturePrefixAndGarbage() {
        let k = LicenseFixtures.key()
        var parts = k.split(separator: ".").map(String.init)
        let evil = LicenseFixtures.b64url(Data(#"{"app":"all","name":"Prueba","issued":"2026-11-11T00:00:00Z"}"#.utf8))
        assertThrows("\(parts[0]).\(evil).\(parts[2])", .invalid)
        var sig = Data(base64Encoded: parts[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "==")!
        sig[0] ^= 1
        parts[2] = LicenseFixtures.b64url(sig)
        assertThrows(parts.joined(separator: "."), .invalid)
        assertThrows(LicenseFixtures.key(prefix: "FERRY"), .invalid, key: LicenseFixtures.publicDER)
        assertThrows(LicenseFixtures.key(prefix: "ALL"), .invalid)
        for junk in ["", "   ", "abc", "CONVOY..", "CONVOY.a.b", "CONVOY.%%%.%%%", "a.b.c.d", String(k.dropLast(10)), String(k.prefix(20))] { assertThrows(junk, .invalid) }
    }

    func testWhitespacePaddingAndOtherPublicKey() throws {
        let k = LicenseFixtures.key()
        XCTAssertNoThrow(try verify("  \n" + k.prefix(30) + "\n " + k.dropFirst(30) + "\r\n"))
        XCTAssertNoThrow(try verify(LicenseFixtures.key(name: "Ñandú", pad: true)))
        XCTAssertNoThrow(try verify(LicenseFixtures.key(name: "Ñandú", pad: false)))
        assertThrows(k, .invalid, key: P256.Signing.PrivateKey().publicKey.derRepresentation.base64EncodedString())
        assertThrows(k, .invalid, key: "no es una clave")
        assertThrows(LicenseFixtures.key(signer: P256.Signing.PrivateKey()), .invalid)
    }

    func testEmbeddedPublicKeyParses() {
        XCTAssertNotNil(Data(base64Encoded: LicenseConstants.publicKeyDER).flatMap { try? P256.Signing.PublicKey(derRepresentation: $0) })
    }
}

final class TrialManagerTests: XCTestCase {
    final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }
    var cal: Calendar { at(2026, 1, 1).1 }
    func day(_ k: Int, _ h: Int = 12) -> Date { cal.date(byAdding: .day, value: k, to: cal.startOfDay(for: at(2026, 11, 11).0))!.addingTimeInterval(Double(h) * 3600) }
    func make(_ date: Date, store: KeyValueStore = MemoryStore(), backup: KeyValueStore = MemoryStore()) -> (TrialManager, Clock) {
        let c = Clock(date)
        return (TrialManager(publicKeyDER: LicenseFixtures.publicDER, store: store, backup: backup, now: { c.now }, calendar: cal), c)
    }
    func secs(_ d: Date) -> String { String(d.timeIntervalSince1970) }
    let fk = TrialManager.firstLaunchKey

    func testFirstLaunchIsRecordedInBothPlacesAndTrialRunsFromThere() {
        let (store, backup) = (MemoryStore(), MemoryStore())
        let (m, clock) = make(day(0), store: store, backup: backup)
        XCTAssertEqual(m.state, .trial(daysLeft: 90))
        XCTAssertEqual(store.string(forKey: fk), secs(day(0)))
        XCTAssertEqual(backup.string(forKey: fk), secs(day(0)))
        clock.now = day(76)
        XCTAssertEqual(m.state, .lastDays(daysLeft: 14))
        clock.now = day(90, 0)
        XCTAssertEqual(m.state, .expired)
        XCTAssertEqual(cal.dateComponents([.month, .day], from: m.endDate), DateComponents(month: 2, day: 8))
    }

    func testOldestFirstLaunchWinsAndMissingOneIsRecreated() {
        let (store, backup) = (MemoryStore(), MemoryStore())
        store.set(secs(day(-50)), forKey: fk)
        backup.set(secs(day(-10)), forKey: fk)
        let (m, _) = make(day(0), store: store, backup: backup)
        XCTAssertEqual(m.state, .trial(daysLeft: 40), "90 - 50")
        XCTAssertEqual(backup.string(forKey: fk), secs(day(-50)), "el registro más reciente se corrige")
        // Borrar las preferencias: se recrean desde el archivo.
        store.set(nil, forKey: fk)
        XCTAssertEqual(make(day(0), store: store, backup: backup).0.state, .trial(daysLeft: 40))
        XCTAssertEqual(store.string(forKey: fk), secs(day(-50)))
        // Borrar el archivo: se recrea desde las preferencias.
        backup.set(nil, forKey: fk)
        XCTAssertEqual(make(day(0), store: store, backup: backup).0.state, .trial(daysLeft: 40))
        XCTAssertEqual(backup.string(forKey: fk), secs(day(-50)))
    }

    func testDeletingBothRestartsTheTrialAndIsDocumentedAsAFreno() {
        let (m, _) = make(day(100))
        XCTAssertEqual(m.state, .trial(daysLeft: 90), "sin ningún registro empieza una prueba nueva (no es DRM)")
    }

    func testMigrationFromFixedDateVersionGivesFull90DaysFromUpdate() {
        // Usuario de 0.2.0: sin firstLaunch, con lastSeen, welcomeSeen y licencia ausente.
        let store = MemoryStore()
        store.set(secs(day(-3)), forKey: "convoy.trial.lastSeen")
        store.set("1", forKey: "convoy.trial.welcomeSeen")
        let (m, clock) = make(day(0), store: store)
        XCTAssertTrue(m.welcomeSeen, "no se repite la bienvenida")
        XCTAssertEqual(m.state, .trial(daysLeft: 90))
        XCTAssertEqual(m.firstLaunch, day(0))
        clock.now = day(89, 23)
        XCTAssertEqual(m.state, .lastDays(daysLeft: 1))
        clock.now = day(90, 0)
        XCTAssertEqual(m.state, .expired)
    }

    func testFutureStoredFirstLaunchIsReplacedByNow() {
        let (store, backup) = (MemoryStore(), MemoryStore())
        store.set(secs(day(300)), forKey: fk); backup.set(secs(day(400)), forKey: fk)
        let (m, _) = make(day(0), store: store, backup: backup)
        XCTAssertEqual(m.state, .trial(daysLeft: 90))
        XCTAssertEqual(store.string(forKey: fk), secs(day(0)))
        XCTAssertEqual(backup.string(forKey: fk), secs(day(0)))
    }

    func testFileStorePersistsAndSurvivesDeletingPreferences() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("convoy-lic-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sub/prueba.json")
        let (m, _) = make(day(0), store: MemoryStore(), backup: FileKeyValueStore(url: url))
        XCTAssertEqual(m.state, .trial(daysLeft: 90))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        // Preferencias nuevas (borradas) + mismo archivo, 30 días después.
        let (m2, _) = make(day(30), store: MemoryStore(), backup: FileKeyValueStore(url: url))
        XCTAssertEqual(m2.state, .trial(daysLeft: 60))
        // Archivo corrupto: se ignora y se recrea.
        try Data("basura".utf8).write(to: url)
        let (m3, _) = make(day(30), store: MemoryStore(), backup: FileKeyValueStore(url: url))
        XCTAssertEqual(m3.state, .trial(daysLeft: 90))
    }

    func testActivateRemoveAndPersistence() throws {
        let (store, backup) = (MemoryStore(), MemoryStore())
        let (m, clock) = make(day(0), store: store, backup: backup)
        clock.now = day(120)
        XCTAssertEqual(m.state, .expired)
        XCTAssertThrowsError(try m.activate("basura")) { XCTAssertEqual($0 as? LicenseError, .invalid) }
        XCTAssertThrowsError(try m.activate(LicenseFixtures.key(app: "ferry"))) { XCTAssertEqual($0 as? LicenseError, .wrongApp) }
        let k = LicenseFixtures.key()
        XCTAssertEqual(try m.activate(k).name, "Prueba")
        XCTAssertEqual(m.state, .licensed)
        XCTAssertThrowsError(try m.activate(k)) { XCTAssertEqual($0 as? LicenseError, .alreadyActive) }
        // Otra instancia con el mismo almacén: se vuelve a verificar al arrancar y no caduca por fecha.
        clock.now = day(5000)
        XCTAssertEqual(make(clock.now, store: store, backup: backup).0.state, .licensed)
        m.removeLicense()
        XCTAssertEqual(m.state, .expired)
    }

    func testTamperedStoredKeyIsNotLicensed() {
        let store = MemoryStore()
        store.set(LicenseFixtures.key(signer: P256.Signing.PrivateKey()), forKey: "convoy.trial.licenseKey")
        store.set(secs(day(-200)), forKey: fk)
        XCTAssertEqual(make(day(0), store: store).0.state, .expired)
    }

    func testLastSeenPersistsSoRewindingTheClockStaysExpired() {
        let (store, backup) = (MemoryStore(), MemoryStore())
        let (m, clock) = make(day(0), store: store, backup: backup)
        clock.now = day(100)
        XCTAssertEqual(m.state, .expired)
        clock.now = day(10)
        XCTAssertEqual(make(clock.now, store: store, backup: backup).0.state, .expired)
        XCTAssertEqual(m.state, .expired)
    }

    func testWelcomeOnceAndDailyReminderOncePerDay() {
        let (m, clock) = make(day(0))
        XCTAssertFalse(m.welcomeSeen); m.markWelcomeSeen(); XCTAssertTrue(m.welcomeSeen)
        XCTAssertNil(m.takeDailyReminder(), "fuera de los últimos 14 días no hay recordatorio")
        clock.now = day(80, 9)
        XCTAssertEqual(m.takeDailyReminder(), 10)
        XCTAssertNil(m.takeDailyReminder(), "una vez por día")
        clock.now = day(80, 23)
        XCTAssertNil(m.takeDailyReminder())
        clock.now = day(81, 8)
        XCTAssertEqual(m.takeDailyReminder(), 9)
        clock.now = day(90, 1)
        XCTAssertNil(m.takeDailyReminder(), "vencida: no hay recordatorio")
    }

    func testGateBlocksOnlyWhenExpired() throws {
        for (k, blocked) in [(5, false), (89, false), (90, true), (300, true)] {
            let store = MemoryStore(); store.set(secs(day(0)), forKey: fk)
            let gate = LicenseGate(manager: make(day(k), store: store).0)
            if blocked { XCTAssertThrowsError(try gate.check()) { XCTAssertEqual($0 as? ConvoyError, .trialExpired) } }
            else { XCTAssertNoThrow(try gate.check()) }
        }
        let store = MemoryStore(); store.set(secs(day(0)), forKey: fk)
        let (m, _) = make(day(500), store: store)
        try m.activate(LicenseFixtures.key())
        XCTAssertNoThrow(try LicenseGate(manager: m).check())
    }

    func testTextsMentionPriceAnd90DaysAndComputedEndDate() {
        XCTAssertEqual(TrialTexts.banner(.trial(daysLeft: 30)), "Versión de prueba · quedan 30 días de 90 · Premium: 10 USD")
        XCTAssertEqual(TrialTexts.banner(.lastDays(daysLeft: 1)), "Último día de prueba · Premium: 10 USD")
        XCTAssertNil(TrialTexts.banner(.licensed)); XCTAssertNil(TrialTexts.banner(.expired))
        let end = TrialTexts.formatDate(TrialPolicy.endDate(firstLaunch: at(2026, 11, 11).0, calendar: cal), calendar: cal, locale: Locale(identifier: "es_CO"))
        XCTAssertTrue(end.contains("2027") && end.contains("8"), end)
        let body = TrialTexts.welcomeBody(endDate: end)
        XCTAssertTrue(body.contains("90 días") && body.contains(end) && body.contains(LicenseConstants.priceText))
        XCTAssertFalse(body.contains("9 de febrero") || body.lowercased().contains("para siempre"))
        XCTAssertTrue(TrialTexts.reminderBody(daysLeft: 3, endDate: end).contains(end))
        XCTAssertTrue(TrialTexts.reminderBody(daysLeft: 1, endDate: end).contains(end))
        XCTAssertTrue(TrialTexts.endLine(endDate: end).contains("90 días") && TrialTexts.endLine(endDate: end).contains(end))
    }

    func testEndDateIsPerPerson() {
        let a = MemoryStore(), b = MemoryStore()
        a.set(secs(day(0)), forKey: fk); b.set(secs(day(40)), forKey: fk)
        let (ma, _) = make(day(50), store: a), (mb, _) = make(day(50), store: b)
        XCTAssertEqual(ma.state, .trial(daysLeft: 40))
        XCTAssertEqual(mb.state, .trial(daysLeft: 80))
        XCTAssertNotEqual(ma.endDate, mb.endDate)
    }
}

/// Prueba extremo a extremo con una clave real emitida por `issue-license.swift` y la clave pública incrustada.
/// Se omite si no hay variable de entorno `CONVOY_TEST_LICENSE_KEY`.
final class EndToEndLicenseTests: XCTestCase {
    func testKeyIssuedByTheRealToolVerifiesWithTheEmbeddedPublicKey() throws {
        guard let key = ProcessInfo.processInfo.environment["CONVOY_TEST_LICENSE_KEY"] else { throw XCTSkip("sin CONVOY_TEST_LICENSE_KEY") }
        let p = try LicenseVerifier.verify(key, app: "convoy", publicKeyDER: LicenseConstants.publicKeyDER)
        XCTAssertEqual(p.app, "convoy")
        let store = MemoryStore()
        store.set("1500000000", forKey: TrialManager.firstLaunchKey)   // año 2017: prueba vencida
        let manager = TrialManager(store: store, now: { Date(timeIntervalSince1970: 1_900_000_000) })   // año 2030
        XCTAssertEqual(manager.state, .expired)
        XCTAssertEqual(try manager.activate(key).name, p.name)
        XCTAssertEqual(manager.state, .licensed)
        XCTAssertThrowsError(try LicenseVerifier.verify(key, app: "ferry", publicKeyDER: LicenseConstants.publicKeyDER))
    }
}

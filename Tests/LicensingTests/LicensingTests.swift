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
    func state(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0, lastSeen: Date? = nil, licensed: Bool = false, tz: String? = nil) -> TrialState {
        let (now, cal) = at(y, m, d, h, min, s, tz: tz)
        return TrialPolicy.state(now: now, lastSeen: lastSeen, licensed: licensed, calendar: cal)
    }

    func testStatesAndBoundaries() {
        XCTAssertEqual(state(2026, 11, 11), .trial(daysLeft: 91))
        XCTAssertEqual(state(2027, 1, 25), .trial(daysLeft: 16))
        XCTAssertEqual(state(2027, 1, 26), .trial(daysLeft: 15), "15 días: aún sin aviso destacado")
        XCTAssertEqual(state(2027, 1, 27), .lastDays(daysLeft: 14), "14 días: últimos días")
        XCTAssertEqual(state(2027, 2, 8), .lastDays(daysLeft: 2))
        XCTAssertEqual(state(2027, 2, 9, 0, 0, 0), .lastDays(daysLeft: 1), "el 9 de febrero es el último día")
        XCTAssertEqual(state(2027, 2, 9, 23, 59, 59), .lastDays(daysLeft: 1))
        XCTAssertEqual(state(2027, 2, 10, 0, 0, 0), .expired, "medianoche: vencida")
        XCTAssertEqual(state(2028, 1, 1), .expired)
    }

    func testClockGoingBackwardsDoesNotReviveTheTrial() {
        let (lastSeen, _) = at(2027, 3, 1)
        XCTAssertEqual(state(2026, 12, 1, lastSeen: lastSeen), .expired)
        let (earlier, _) = at(2026, 12, 1)
        XCTAssertEqual(state(2027, 1, 30, lastSeen: earlier), .lastDays(daysLeft: 11), "un lastSeen anterior no cambia nada")
    }

    func testLicenseWinsOverEverything() {
        XCTAssertEqual(state(2030, 1, 1, licensed: true), .licensed)
        XCTAssertEqual(state(2026, 12, 1, licensed: true), .licensed)
    }

    func testTimeZonesAndDSTDoNotShiftByADay() {
        for tz in ["America/Bogota", "America/New_York", "Europe/Madrid", "Pacific/Auckland", "Asia/Tokyo"] {
            XCTAssertEqual(state(2027, 2, 9, 23, 59, 59, tz: tz), .lastDays(daysLeft: 1), tz)
            XCTAssertEqual(state(2027, 2, 10, 0, 0, 0, tz: tz), .expired, tz)
            // Cruce de horario de verano (EE. UU. 14 de marzo de 2027 es posterior; usamos 2026-11-01, fin de DST).
            XCTAssertEqual(state(2026, 11, 1, 12, tz: tz), .trial(daysLeft: 101), tz)
            XCTAssertEqual(state(2026, 11, 2, 12, tz: tz), .trial(daysLeft: 100), tz)
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
    func make(_ date: Date, store: KeyValueStore = MemoryStore()) -> (TrialManager, Clock, KeyValueStore) {
        let c = Clock(date)
        return (TrialManager(publicKeyDER: LicenseFixtures.publicDER, store: store, now: { c.now }, calendar: cal), c, store)
    }

    func testActivateRemoveAndPersistence() throws {
        let (m, clock, store) = make(at(2027, 3, 1).0)
        XCTAssertEqual(m.state, .expired)
        XCTAssertThrowsError(try m.activate("basura")) { XCTAssertEqual($0 as? LicenseError, .invalid) }
        XCTAssertThrowsError(try m.activate(LicenseFixtures.key(app: "ferry"))) { XCTAssertEqual($0 as? LicenseError, .wrongApp) }
        let k = LicenseFixtures.key()
        XCTAssertEqual(try m.activate(k).name, "Prueba")
        XCTAssertEqual(m.state, .licensed)
        XCTAssertThrowsError(try m.activate(k)) { XCTAssertEqual($0 as? LicenseError, .alreadyActive) }
        // Otra instancia con el mismo almacén: se vuelve a verificar al arrancar y no caduca por fecha.
        clock.now = at(2035, 1, 1).0
        XCTAssertEqual(make(clock.now, store: store).0.state, .licensed)
        m.removeLicense()
        XCTAssertEqual(m.state, .expired)
    }

    func testTamperedStoredKeyIsNotLicensed() {
        let store = MemoryStore()
        store.set(LicenseFixtures.key(signer: P256.Signing.PrivateKey()), forKey: "convoy.trial.licenseKey")
        XCTAssertEqual(make(at(2027, 3, 1).0, store: store).0.state, .expired)
    }

    func testLastSeenPersistsSoRewindingTheClockStaysExpired() {
        let (m, clock, store) = make(at(2027, 2, 20).0)
        XCTAssertEqual(m.state, .expired)
        clock.now = at(2026, 12, 1).0
        XCTAssertEqual(make(clock.now, store: store).0.state, .expired)
    }

    func testWelcomeOnceAndDailyReminderOncePerDay() {
        let (m, clock, _) = make(at(2026, 12, 1).0)
        XCTAssertFalse(m.welcomeSeen); m.markWelcomeSeen(); XCTAssertTrue(m.welcomeSeen)
        XCTAssertNil(m.takeDailyReminder(), "fuera de los últimos 14 días no hay recordatorio")
        clock.now = at(2027, 1, 30, 9).0
        XCTAssertEqual(m.takeDailyReminder(), 11)
        XCTAssertNil(m.takeDailyReminder(), "una vez por día")
        clock.now = at(2027, 1, 30, 23).0
        XCTAssertNil(m.takeDailyReminder())
        clock.now = at(2027, 1, 31, 8).0
        XCTAssertEqual(m.takeDailyReminder(), 10)
        clock.now = at(2027, 2, 10).0
        XCTAssertNil(m.takeDailyReminder(), "vencida: no hay recordatorio")
    }

    func testGateBlocksOnlyWhenExpired() throws {
        for (date, blocked) in [(at(2026, 12, 1).0, false), (at(2027, 2, 9).0, false), (at(2027, 2, 10).0, true)] {
            let gate = LicenseGate(manager: make(date).0)
            if blocked { XCTAssertThrowsError(try gate.check()) { XCTAssertEqual($0 as? ConvoyError, .trialExpired) } }
            else { XCTAssertNoThrow(try gate.check()) }
        }
        let (m, _, _) = make(at(2027, 5, 1).0)
        try m.activate(LicenseFixtures.key())
        XCTAssertNoThrow(try LicenseGate(manager: m).check())
    }

    func testTextsMentionPriceAndEndDate() {
        XCTAssertEqual(TrialTexts.banner(.trial(daysLeft: 30)), "Versión de prueba · quedan 30 días · Premium: 10 USD")
        XCTAssertEqual(TrialTexts.banner(.lastDays(daysLeft: 1)), "Último día de prueba · Premium: 10 USD")
        XCTAssertNil(TrialTexts.banner(.licensed)); XCTAssertNil(TrialTexts.banner(.expired))
        XCTAssertTrue(TrialTexts.welcomeBody.contains("9 de febrero de 2027") && TrialTexts.welcomeBody.contains(LicenseConstants.priceText))
        XCTAssertFalse(TrialTexts.welcomeBody.lowercased().contains("para siempre"))
    }
}

/// Prueba extremo a extremo con una clave real emitida por `issue-license.swift` y la clave pública incrustada.
/// Se omite si no hay variable de entorno `CONVOY_TEST_LICENSE_KEY`.
final class EndToEndLicenseTests: XCTestCase {
    func testKeyIssuedByTheRealToolVerifiesWithTheEmbeddedPublicKey() throws {
        guard let key = ProcessInfo.processInfo.environment["CONVOY_TEST_LICENSE_KEY"] else { throw XCTSkip("sin CONVOY_TEST_LICENSE_KEY") }
        let p = try LicenseVerifier.verify(key, app: "convoy", publicKeyDER: LicenseConstants.publicKeyDER)
        XCTAssertEqual(p.app, "convoy")
        let manager = TrialManager(store: MemoryStore(), now: { Date(timeIntervalSince1970: 1_900_000_000) })   // año 2030
        XCTAssertEqual(manager.state, .expired)
        XCTAssertEqual(try manager.activate(key).name, p.name)
        XCTAssertEqual(manager.state, .licensed)
        XCTAssertThrowsError(try LicenseVerifier.verify(key, app: "ferry", publicKeyDER: LicenseConstants.publicKeyDER))
    }
}

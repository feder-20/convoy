import XCTest
import ConvoyDomain
@testable import ConvoyApp

final class LocalizationTests: XCTestCase {
    var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }

    func englishTable() throws -> [String: String] {
        let url = root.appendingPathComponent("Resources/en.lproj/Localizable.strings")
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
    }
    func specs(_ s: String) -> [String] {
        let r = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?[@d]")
        return r.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }.sorted()
    }

    func testEveryKeyUsedInCodeHasAnEnglishTranslationWithSameSpecifiers() throws {
        let table = try englishTable()
        var keys = Set<String>()
        let files = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let call = try NSRegularExpression(pattern: #"\b(?:L|tr)\("((?:[^"\\]|\\.)*)""#)
        for f in files {
            let s = try String(contentsOf: f, encoding: .utf8)
            for m in call.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
                if let r = Range(m.range(at: 1), in: s) { keys.insert(String(s[r]).replacingOccurrences(of: "\\\"", with: "\"")) }
            }
        }
        XCTAssertGreaterThan(keys.count, 60)
        let missing = keys.filter { table[$0] == nil }.sorted()
        XCTAssertTrue(missing.isEmpty, "Sin traducción al inglés: \(missing)")
        for k in keys { if let v = table[k] { XCTAssertEqual(specs(k), specs(v), "Marcadores distintos en «\(k)»") } }
        let stale = table.keys.filter { !keys.contains($0) }.sorted()
        XCTAssertTrue(stale.isEmpty, "Traducciones sin uso: \(stale)")
    }

    func testEnglishBundleTranslatesAppAndCoreMessages() throws {
        let bundle = try XCTUnwrap(Bundle(path: root.appendingPathComponent("Resources/en.lproj").path))
        Localization.bundle = bundle
        defer { Localization.bundle = .main }
        XCTAssertEqual(L("Crear proyecto · %d carpetas", 13), "Create project · 13 folders")
        XCTAssertEqual(ConvoyError.alreadyExists("X").localizedDescription, "There is already a folder named “X” here.")
        XCTAssertEqual(NamingWarning.replacedCharacters.message, "Characters that Windows does not allow were replaced.")
        XCTAssertEqual(NamingWarning.longPath(214).message, "The longest path is 214 characters. Some Windows apps cannot open files with paths longer than 260.")
        Localization.bundle = .main
        XCTAssertEqual(L("Crear otro"), "Crear otro")
    }
}

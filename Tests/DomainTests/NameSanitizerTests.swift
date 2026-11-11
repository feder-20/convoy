import XCTest
import ConvoyDomain

final class NameSanitizerTests: XCTestCase {
    func s(_ raw: String, strip: Bool = false) throws -> SanitizedName { try NameSanitizer.sanitize(raw, stripAccents: strip) }

    func testEveryForbiddenCharacterBecomesDashAndIsReported() throws {
        for c in ["\"", "*", ":", "<", ">", "?", "/", "\\", "|"] {
            let r = try s("a\(c)b")
            XCTAssertEqual(r.value, "a-b", "carácter \(c)")
            XCTAssertTrue(r.replacedCharacters)
        }
        let control = try s("a\tb\nc\u{7}d")
        XCTAssertEqual(control.value, "a-b-c-d")
        XCTAssertTrue(control.replacedCharacters)
        XCTAssertFalse(try s("Expansión Perú").replacedCharacters)
    }

    func testSpacesAndTrailingDots() throws {
        XCTAssertEqual(try s("   Plan   de   obra  ").value, "Plan de obra")
        XCTAssertEqual(try s("Informe...").value, "Informe")
        XCTAssertEqual(try s("Informe . .").value, "Informe")
        XCTAssertEqual(try s("a\u{00A0}\u{00A0}b").value, "a b", "el espacio de no separación cuenta como espacio")
    }

    func testReservedNames() {
        for name in ["CON", "con", "PRN", "AUX", "NUL", "COM0", "COM9", "LPT1", "lpt9", "con.txt", "NUL.tar.gz", ".lock", "desktop.ini", "Desktop.INI", "~$Plan", "a_vti_b"] {
            XCTAssertThrowsError(try s(name), name) { error in
                guard case ConvoyError.reservedName = error else { return XCTFail("\(name): \(error)") }
            }
        }
        for ok in ["CONTRATOS", "Console", "COM10", "LPT", "Aux1", "lock"] { XCTAssertNoThrow(try s(ok), ok) }
    }

    func testUnicodeIsNormalizedToNFC() throws {
        let nfd = "Expansio\u{301}n Peru\u{301} Man\u{303}ana"          // é, ú y ñ descompuestas
        let r = try s(nfd)
        XCTAssertEqual(r.value, "Expansión Perú Mañana")
        XCTAssertEqual(r.value.unicodeScalars.count, "Expansión Perú Mañana".unicodeScalars.count)
        XCTAssertEqual(r.value, r.value.precomposedStringWithCanonicalMapping)
    }

    func testStripAccentsKeepsEnye() throws {
        XCTAssertEqual(try s("Expansión Perú", strip: true).value, "Expansion Peru")
        XCTAssertEqual(try s("Año Ñandú Über", strip: true).value, "Año Ñandu Uber", "la ñ se conserva")
        XCTAssertEqual(try s("Man\u{303}ana ca\u{301}fe", strip: true).value, "Mañana cafe", "también en forma descompuesta")
    }

    func testMaxLengthAndEmpty() throws {
        let long = try s(String(repeating: "a", count: 120))
        XCTAssertEqual(long.value.count, 80)
        XCTAssertTrue(long.truncated)
        // Al cortar en 80 podría quedar un punto al final, que Windows no permite: se quita.
        XCTAssertEqual(try s(String(repeating: "a", count: 79) + ". b").value, String(repeating: "a", count: 79))
    }

    func testEmptyAfterCleaningThrows() {
        for raw in ["", "   ", "...", " . "] {
            XCTAssertThrowsError(try s(raw), raw) { XCTAssertEqual($0 as? ConvoyError, .emptyName) }
        }
        XCTAssertEqual(try s("???").value, "---", "solo caracteres no válidos: quedan guiones")
    }
}

final class TemplateEditingTests: XCTestCase {
    func base() -> Template { Template(name: "T", folders: [FolderNode(name: "A", children: [FolderNode(name: "a1"), FolderNode(name: "a2")]), FolderNode(name: "B"), FolderNode(name: "C")]) }

    func testAddRenameRemoveAndMove() {
        var t = base()
        t.addFolder(named: "  D  ")
        t.addFolder(named: "   ")
        XCTAssertEqual(t.folders.map(\.name), ["A", "B", "C", "D"])
        let a = t.folders[0]
        t.addSubfolder(named: "a3", to: a.id)
        XCTAssertEqual(t.folders[0].children.map(\.name), ["a1", "a2", "a3"])
        t.rename(folder: a.children[0].id, to: "uno")
        t.rename(folder: a.id, to: "Alfa")
        XCTAssertEqual(t.folders[0].name, "Alfa"); XCTAssertEqual(t.folders[0].children[0].name, "uno")
        t.move(folder: t.folders[2].id, by: -1)
        XCTAssertEqual(t.folders.map(\.name), ["Alfa", "C", "B", "D"])
        t.move(folder: t.folders[0].id, by: -1)                       // ya es el primero: no cambia
        XCTAssertEqual(t.folders.first?.name, "Alfa")
        t.move(folder: t.folders[0].children[2].id, by: -1)
        XCTAssertEqual(t.folders[0].children.map(\.name), ["uno", "a3", "a2"])
        t.remove(folder: t.folders[0].children[1].id)
        t.remove(folder: t.folders[1].id)
        XCTAssertEqual(t.folders.map(\.name), ["Alfa", "B", "D"])
        XCTAssertEqual(t.folders[0].children.map(\.name), ["uno", "a2"])
        XCTAssertEqual(t.folderCount, 5)
    }

    func testDuplicateGetsNewIdentifiersAndIsNotBuiltIn() {
        var original = base(); original.isBuiltIn = true
        let copy = original.duplicated(named: "T copia")
        XCTAssertFalse(copy.isBuiltIn)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.folders.map(\.name), original.folders.map(\.name))
        XCTAssertTrue(Set(copy.folders.map(\.id)).isDisjoint(with: Set(original.folders.map(\.id))))
        XCTAssertTrue(Set(copy.folders[0].children.map(\.id)).isDisjoint(with: Set(original.folders[0].children.map(\.id))))
    }
}

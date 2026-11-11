import Foundation

public struct SanitizedName: Equatable, Sendable {
    public let value: String
    public let replacedCharacters: Bool
    public let truncated: Bool
}

/// Convención de nombres compatible con Windows, OneDrive y SharePoint (convoy.md §6.2).
public enum NameSanitizer {
    public static let maxSegmentLength = 80
    static let invalid: Set<Character> = ["\"", "*", ":", "<", ">", "?", "/", "\\", "|"]
    static let reserved: Set<String> = {
        var s: Set<String> = ["CON", "PRN", "AUX", "NUL"]
        for i in 0...9 { s.insert("COM\(i)"); s.insert("LPT\(i)") }
        return s
    }()

    public static func sanitize(_ raw: String, stripAccents: Bool = false, maxLength: Int = maxSegmentLength) throws -> SanitizedName {
        // 1. Recortar espacios y reducir los múltiples a uno.
        var chars: [Character] = []
        for c in raw {
            let isSpace = c == " " || c == "\u{00A0}"
            if isSpace, chars.last == " " || chars.isEmpty { continue }
            chars.append(isSpace ? " " : c)
        }
        while chars.last == " " { chars.removeLast() }

        // 2. Reemplazar caracteres no válidos (y de control) por guion.
        var replaced = false
        chars = chars.map { c in
            let control = c.unicodeScalars.contains { $0.value < 32 || (0x7F...0x9F).contains($0.value) }
            if invalid.contains(c) || control { replaced = true; return "-" }
            return c
        }

        // 3. Quitar puntos (y espacios) al final.
        while let last = chars.last, last == "." || last == " " { chars.removeLast() }
        var value = String(chars)

        // 4. Nombres reservados.
        let upperBase = value.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map { $0.uppercased() } ?? ""
        let lower = value.lowercased()
        if reserved.contains(upperBase) || lower == ".lock" || lower == "desktop.ini" || value.hasPrefix("~$") || lower.contains("_vti_") {
            throw ConvoyError.reservedName(value)
        }

        // 5. Unicode NFC.
        value = value.precomposedStringWithCanonicalMapping

        // 6. Quitar tildes (se conserva la ñ).
        if stripAccents { value = removeAccents(value) }

        // 7. Máximo de caracteres por segmento.
        var truncated = false
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
            truncated = true
            while let last = value.last, last == "." || last == " " { value.removeLast() }
        }
        guard !value.isEmpty else { throw ConvoyError.emptyName }
        return SanitizedName(value: value, replacedCharacters: replaced, truncated: truncated)
    }

    static func removeAccents(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        var previousBase: Unicode.Scalar?
        for scalar in s.decomposedStringWithCanonicalMapping.unicodeScalars {
            if scalar.properties.generalCategory == .nonspacingMark {
                let keepTilde = scalar.value == 0x0303 && (previousBase == "n" || previousBase == "N")
                if !keepTilde { continue }
            } else { previousBase = scalar }
            out.append(scalar)
        }
        return String(out).precomposedStringWithCanonicalMapping
    }
}

/// Presupuesto de longitud de ruta (convoy.md §6.2, regla 8).
public enum PathBudget {
    public static let warnAbove = 200
    public static let blockAbove = 400

    public static func isBlocked(_ length: Int) -> Bool { length > blockAbove }
    public static func shouldWarn(_ length: Int) -> Bool { length > warnAbove }
}

import Foundation

public struct SanitizedName: Equatable, Sendable {
    public let value: String
    public let replacedCharacters: Bool
    public let truncated: Bool
}

/// Convención de nombres compatible con Windows, OneDrive y SharePoint (convoy.md §6.2).
/// El saneado trabaja por escalares Unicode (no por `Character`): una marca combinante detrás de «/» o «:»
/// formaría un solo `Character` que ya no estaría en la lista de inválidos.
public enum NameSanitizer {
    public static let maxSegmentLength = 80
    /// Un nombre de carpeta cabe en 255 bytes UTF-8 en APFS/NTFS.
    public static let maxSegmentBytes = 255
    static let invalidScalars: Set<Unicode.Scalar> = ["\"", "*", ":", "<", ">", "?", "/", "\\", "|"]
    static let reserved: Set<String> = {
        var s: Set<String> = ["CON", "PRN", "AUX", "NUL"]
        for i in 0...9 { s.insert("COM\(i)"); s.insert("LPT\(i)") }
        return s
    }()

    /// Controles, separadores de línea, formato (cero ancho, bidi, BOM, guion blando) y etiquetas.
    static func isForbidden(_ s: Unicode.Scalar) -> Bool {
        if invalidScalars.contains(s) { return true }
        switch s.value {
        case 0x0000...0x001F, 0x007F...0x009F, 0x2028, 0x2029, 0x200B...0x200F, 0x202A...0x202E,
             0x2066...0x2069, 0xFEFF, 0x00AD, 0xE0000...0xE007F: return true
        default: return false
        }
    }

    static func isSpace(_ s: Unicode.Scalar) -> Bool { s == " " || s.properties.generalCategory == .spaceSeparator }

    /// Reemplaza por «-» los escalares prohibidos. Devuelve el texto y si hubo reemplazos.
    static func replaceForbidden(_ input: String.UnicodeScalarView) -> (String.UnicodeScalarView, Bool) {
        var out = String.UnicodeScalarView(), replaced = false
        for s in input {
            if isForbidden(s) { out.append("-"); replaced = true } else { out.append(s) }
        }
        return (out, replaced)
    }

    /// Recorta a `maxLength` caracteres y a `maxBytes` bytes UTF-8, y quita puntos y espacios finales.
    public static func truncate(_ value: String, maxLength: Int = maxSegmentLength, maxBytes: Int = maxSegmentBytes) -> (value: String, truncated: Bool) {
        var v = value
        var truncated = false
        if v.count > maxLength { v = String(v.prefix(maxLength)); truncated = true }
        while v.utf8.count > maxBytes, !v.isEmpty {
            // Un solo carácter con cientos de marcas combinantes: se recorta por escalares.
            if v.count > 1 { v.removeLast() } else { var u = v.unicodeScalars; u.removeLast(); v = String(u) }
            truncated = true
        }
        if truncated { while let last = v.last, last == "." || last == " " { v.removeLast() } }
        return (v, truncated)
    }

    public static func sanitize(_ raw: String, stripAccents: Bool = false, maxLength: Int = maxSegmentLength) throws -> SanitizedName {
        // 1. Reemplazar caracteres no válidos, de control y de formato por guion (por escalares).
        var (scalars, replaced) = replaceForbidden(raw.unicodeScalars)

        // 2. Espacios Unicode: múltiples a uno y recorte al inicio y al final.
        var spaced = String.UnicodeScalarView()
        var lastWasSpace = true
        for s in scalars {
            if isSpace(s) {
                if !lastWasSpace { spaced.append(" ") }
                lastWasSpace = true
            } else { spaced.append(s); lastWasSpace = false }
        }
        scalars = spaced
        while scalars.last == " " { scalars.removeLast() }

        // 3. Quitar puntos (y espacios) al final.
        while let last = scalars.last, last == "." || last == " " { scalars.removeLast() }
        var value = String(scalars)

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

        // 7. Defensa final: la normalización no puede reintroducir un escalar prohibido.
        let (again, replacedAgain) = replaceForbidden(value.unicodeScalars)
        if replacedAgain { value = String(again); replaced = true }

        // 8. Máximo de caracteres y de bytes UTF-8 por segmento.
        let cut = truncate(value, maxLength: maxLength)
        value = cut.value
        guard !value.isEmpty else { throw ConvoyError.emptyName }
        return SanitizedName(value: value, replacedCharacters: replaced, truncated: cut.truncated)
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

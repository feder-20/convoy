import Foundation
import CryptoKit

public struct LicensePayload: Equatable, Sendable, Codable {
    public let app: String
    public let name: String
    public let issued: String
}

public enum LicenseError: Error, Equatable, Sendable {
    case invalid, wrongApp, alreadyActive
}

/// Verificación sin internet: `APP.<payload>.<firma>` con payload y firma en base64url sin relleno.
/// La firma es ECDSA P-256 / SHA-256 (r‖s, 64 bytes) sobre los bytes exactos del payload.
public enum LicenseVerifier {
    /// Quita espacios y saltos de línea (también al pegar una clave partida en varias líneas).
    public static func clean(_ raw: String) -> String {
        String(String.UnicodeScalarView(raw.unicodeScalars.filter { !$0.properties.isWhitespace }))
    }

    static func base64URLDecode(_ s: String) -> Data? {
        var t = s
        while t.hasSuffix("=") { t.removeLast() }
        let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        guard !t.isEmpty, t.allSatisfy({ alphabet.contains($0) }) else { return nil }
        t = t.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        t += String(repeating: "=", count: (4 - t.count % 4) % 4)
        return Data(base64Encoded: t)
    }

    public static func verify(_ raw: String, app: String, publicKeyDER: String) throws -> LicensePayload {
        let key = clean(raw)
        let parts = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let payloadData = base64URLDecode(parts[1]), let sigData = base64URLDecode(parts[2]),
              let der = Data(base64Encoded: publicKeyDER),
              let publicKey = try? P256.Signing.PublicKey(derRepresentation: der),
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: sigData),
              publicKey.isValidSignature(signature, for: payloadData),
              let payload = try? JSONDecoder().decode(LicensePayload.self, from: payloadData)
        else { throw LicenseError.invalid }
        let target = payload.app.lowercased()
        guard parts[0].lowercased() == target else { throw LicenseError.invalid }
        guard target == app.lowercased() || target == "all" else { throw LicenseError.wrongApp }
        return payload
    }
}

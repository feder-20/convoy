import Foundation
import ConvoyDomain

/// Texto localizado. El español es la clave y el idioma base; el inglés va en `en.lproj`.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: Localization.bundle, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

/// «Documentos › Proyectos»: las dos últimas carpetas con el nombre que ve el usuario en el Finder.
func breadcrumb(_ url: URL) -> String {
    let parts = url.standardizedFileURL.pathComponents.filter { $0 != "/" }
    guard !parts.isEmpty else { return "/" }
    var shown: [String] = []
    var path = ""
    for p in parts { path += "/" + p; shown.append(FileManager.default.displayName(atPath: path)) }
    return shown.suffix(2).joined(separator: " › ")
}

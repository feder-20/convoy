import Foundation

/// Idioma de los textos que genera el núcleo (errores, avisos). Las pruebas pueden cambiarlo.
public enum Localization {
    public nonisolated(unsafe) static var bundle: Bundle = .main
}

/// Texto localizado: el español es la clave y el idioma base; `en.lproj` trae el inglés.
public func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: Localization.bundle, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

public struct FolderNode: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var children: [FolderNode]          // MVP: un nivel

    public init(id: UUID = UUID(), name: String, children: [FolderNode] = []) {
        self.id = id
        self.name = name
        self.children = children
    }
}

public struct Template: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isBuiltIn: Bool
    public var folders: [FolderNode]
    public var schemaVersion: Int = 1

    public init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, folders: [FolderNode], schemaVersion: Int = 1) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.folders = folders
        self.schemaVersion = schemaVersion
    }

    /// Carpetas que se crean dentro de la madre (primer nivel y subcarpetas).
    public var folderCount: Int { folders.reduce(0) { $0 + 1 + $1.children.count } }
}

public struct ProjectRequest: Sendable {
    public var projectName: String
    public var template: Template
    public var destination: URL
    public var includeProjectNameInFolders: Bool

    public init(projectName: String, template: Template, destination: URL, includeProjectNameInFolders: Bool) {
        self.projectName = projectName
        self.template = template
        self.destination = destination
        self.includeProjectNameInFolders = includeProjectNameInFolders
    }
}

public struct PlannedFolder: Sendable, Hashable {
    /// Segmentos desde la carpeta madre (sin incluirla).
    public let relativePath: [String]
    public init(relativePath: [String]) { self.relativePath = relativePath }
    public var depth: Int { relativePath.count }
    public var name: String { relativePath.last ?? "" }
}

public enum NamingWarning: Sendable, Equatable {
    case replacedCharacters
    case truncated
    case longPath(Int)

    public var message: String {
        switch self {
        case .replacedCharacters: return tr("Se reemplazaron caracteres que Windows no permite.")
        case .truncated: return tr("Se acortaron nombres de más de 80 caracteres.")
        case .longPath(let n): return tr("La ruta más larga tiene %d caracteres. Algunas apps de Windows no abren archivos con rutas de más de 260.", n)
        }
    }
}

public struct CreationPlan: Sendable {
    public let rootName: String
    public let folders: [PlannedFolder]
    /// Longitud en caracteres de la ruta absoluta más larga del árbol resultante.
    public let longestPathLength: Int
    public let warnings: [NamingWarning]
    public var folderCount: Int { folders.count }

    public init(rootName: String, folders: [PlannedFolder], longestPathLength: Int, warnings: [NamingWarning]) {
        self.rootName = rootName
        self.folders = folders
        self.longestPathLength = longestPathLength
        self.warnings = warnings
    }
}

public struct CreationResult: Sendable {
    public let url: URL
    public let folderCount: Int
    public init(url: URL, folderCount: Int) { self.url = url; self.folderCount = folderCount }
}

public enum ConvoyError: Error, Equatable, LocalizedError {
    case emptyName, emptyTemplate, reservedName(String)
    case pathTooLong(Int), alreadyExists(String)
    case noPermission(URL), creationFailed(String)
    case tooManyFolders, duplicateFolder(String)
    case invalidTemplateFile(String), builtInTemplate
    case trialExpired

    public var errorDescription: String? {
        switch self {
        case .emptyName: return tr("Escribe el nombre del proyecto.")
        case .emptyTemplate: return tr("La plantilla no tiene carpetas.")
        case .reservedName(let n): return tr("«%@» es un nombre que Windows no permite.", n)
        case .pathTooLong(let n): return tr("La ruta más larga tendría %d caracteres. Acorta el nombre del proyecto o el de las carpetas.", n)
        case .alreadyExists(let n): return tr("Ya hay una carpeta llamada «%@» aquí.", n)
        case .noPermission(let u): return tr("Convoy necesita permiso para crear carpetas en %@.", u.lastPathComponent)
        case .creationFailed(let where_): return tr("No se pudo crear el proyecto. No se cambió nada en %@.", where_)
        case .tooManyFolders: return tr("Una plantilla admite hasta 99 carpetas de primer nivel.")
        case .duplicateFolder(let n): return tr("La plantilla tiene dos carpetas con el nombre «%@».", n)
        case .invalidTemplateFile(let why): return tr("El archivo de plantilla no es válido. %@", why)
        case .trialExpired: return tr("El periodo de prueba terminó. Activa Convoy premium para crear proyectos.")
        case .builtInTemplate: return tr("Las plantillas de fábrica no se pueden cambiar. Duplícala para editarla.")
        }
    }
}

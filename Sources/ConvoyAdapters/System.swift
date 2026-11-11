import AppKit
import ConvoyDomain
import ConvoyPorts

public struct NSWorkspaceRevealer: FinderRevealer {
    public init() {}
    public func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}

/// Carpetas recordadas como marcadores de seguridad: sirven con y sin sandbox.
public final class BookmarkLocationAccess: LocationAccess, @unchecked Sendable {
    private let defaults: UserDefaults
    private let maxRecent: Int
    private let recentKey = "convoy.recentBookmarks"
    private let defaultKey = "convoy.defaultBookmark"

    public init(defaults: UserDefaults = .standard, maxRecent: Int = 6) {
        self.defaults = defaults
        self.maxRecent = maxRecent
    }

    public func withAccess<T: Sendable>(to url: URL, _ body: () async throws -> T) async throws -> T {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        return try await body()
    }

    public func remember(_ url: URL) throws {
        let data = try bookmark(url)
        var list = (defaults.array(forKey: recentKey) as? [Data] ?? []).filter { resolve($0)?.standardizedFileURL.path != url.standardizedFileURL.path }
        list.insert(data, at: 0)
        defaults.set(Array(list.prefix(maxRecent)), forKey: recentKey)
    }

    public func recent() -> [URL] {
        (defaults.array(forKey: recentKey) as? [Data] ?? []).compactMap(resolve).filter { isDirectory($0) }
    }

    public func defaultLocation() -> URL? {
        guard let data = defaults.data(forKey: defaultKey), let url = resolve(data), isDirectory(url) else { return nil }
        return url
    }

    public func setDefaultLocation(_ url: URL) throws {
        defaults.set(try bookmark(url), forKey: defaultKey)
    }

    private func bookmark(_ url: URL) throws -> Data {
        if let d = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) { return d }
        return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func resolve(_ data: Data) -> URL? {
        var stale = false
        if let u = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) { return u }
        return try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

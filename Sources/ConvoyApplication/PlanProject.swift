import Foundation
import ConvoyDomain

/// Valida la solicitud y calcula todo lo que se va a crear, sin tocar el disco (convoy.md §8.2).
public struct PlanProject: Sendable {
    public init() {}

    public func callAsFunction(_ request: ProjectRequest, stripAccents: Bool = false) throws -> CreationPlan {
        guard !request.template.folders.isEmpty else { throw ConvoyError.emptyTemplate }
        guard request.template.folders.count <= 99 else { throw ConvoyError.tooManyFolders }

        var replaced = false, truncated = false
        func clean(_ raw: String) throws -> String {
            let s = try NameSanitizer.sanitize(raw, stripAccents: stripAccents)
            replaced = replaced || s.replacedCharacters
            truncated = truncated || s.truncated
            return s.value
        }

        let root = try clean(request.projectName)
        var planned: [PlannedFolder] = []
        var firstLevel = Set<String>()

        for (index, node) in request.template.folders.enumerated() {
            let type = try clean(node.name)
            let number = String(format: "%02d", index + 1)
            var segment = request.includeProjectNameInFolders ? "\(number)_\(root)_\(type)" : "\(number)_\(type)"
            if segment.count > NameSanitizer.maxSegmentLength {
                segment = String(segment.prefix(NameSanitizer.maxSegmentLength))
                while let last = segment.last, last == "." || last == " " { segment.removeLast() }
                truncated = true
            }
            guard firstLevel.insert(segment.lowercased()).inserted else { throw ConvoyError.duplicateFolder(node.name) }
            planned.append(PlannedFolder(relativePath: [segment]))

            var children = Set<String>()
            for child in node.children {
                let name = try clean(child.name)
                guard children.insert(name.lowercased()).inserted else { throw ConvoyError.duplicateFolder(child.name) }
                planned.append(PlannedFolder(relativePath: [segment, name]))
            }
        }

        let base = request.destination.path
        let longest = planned.map { folder in
            (base + "/" + ([root] + folder.relativePath).joined(separator: "/")).count
        }.max() ?? (base + "/" + root).count
        if PathBudget.isBlocked(longest) { throw ConvoyError.pathTooLong(longest) }

        var warnings: [NamingWarning] = []
        if replaced { warnings.append(.replacedCharacters) }
        if truncated { warnings.append(.truncated) }
        if PathBudget.shouldWarn(longest) { warnings.append(.longPath(longest)) }
        return CreationPlan(rootName: root, folders: planned, longestPathLength: longest, warnings: warnings)
    }
}

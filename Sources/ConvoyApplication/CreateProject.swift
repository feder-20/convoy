import Foundation
import ConvoyDomain
import ConvoyPorts

/// Caso de uso: planifica, comprueba que la carpeta madre no exista y crea todo o nada.
public struct CreateProject: Sendable {
    private let plan = PlanProject()
    private let writer: FolderWriter
    private let access: LocationAccess

    public init(writer: FolderWriter, access: LocationAccess) {
        self.writer = writer
        self.access = access
    }

    public func callAsFunction(_ request: ProjectRequest, stripAccents: Bool = false) async throws -> CreationResult {
        let creation = try plan(request, stripAccents: stripAccents)
        let url = try await access.withAccess(to: request.destination) {
            if try writer.exists(creation.rootName, in: request.destination) {
                throw ConvoyError.alreadyExists(creation.rootName)
            }
            return try await writer.create(creation, in: request.destination)
        }
        try? access.remember(request.destination)
        return CreationResult(url: url, folderCount: creation.folderCount)
    }
}

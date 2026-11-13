import AppKit
import Observation
import ConvoyDomain
import ConvoyPorts
import ConvoyLicensing

/// Puente entre la lógica pura de la prueba (`TrialManager`) y la interfaz. El abridor de URL se inyecta.
@MainActor
@Observable
final class TrialController {
    private(set) var state: TrialState
    private(set) var buyer: String?
    let manager: TrialManager
    @ObservationIgnored private let opener: (URL) -> Void

    init(manager: TrialManager, opener: @escaping (URL) -> Void) {
        self.manager = manager
        self.opener = opener
        self.state = manager.state
        self.buyer = manager.license?.name
    }

    static func live() -> TrialController {
        TrialController(manager: TrialManager(store: UserDefaultsStore(), backup: FileKeyValueStore.standard()), opener: { NSWorkspace.shared.open($0) })
    }

    var gate: ExecutionGate { LicenseGate(manager: manager) }
    var isExpired: Bool { state == .expired }
    var isLicensed: Bool { state == .licensed }

    func refresh() { state = manager.state; buyer = manager.license?.name }

    func openPurchase() { opener(LicenseConstants.purchaseURL) }

    /// Devuelve un mensaje de error o nil si la clave se activó.
    func activate(_ key: String) -> String? {
        do { try manager.activate(key); refresh(); return nil }
        catch let e as LicenseError { return TrialTexts.message(for: e) }
        catch { return TrialTexts.message(for: .invalid) }
    }

    func removeLicense() { manager.removeLicense(); refresh() }

    var endDateText: String { TrialTexts.formatDate(manager.endDate) }
    var trialEndText: String { TrialTexts.endLine(endDate: endDateText) }
}

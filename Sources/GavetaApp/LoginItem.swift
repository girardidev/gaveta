import Observation
import ServiceManagement

/// "Iniciar com o macOS" backed by `SMAppService.mainApp` (works only from a signed/bundled app).
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled: Bool
    private(set) var errorMessage: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not change launch at login: \(error.localizedDescription)"
        }
        refresh()
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            errorMessage = "Approve Gaveta in System Settings › General › Login Items."
        }
    }
}

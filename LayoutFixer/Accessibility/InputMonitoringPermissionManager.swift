import AppKit
import CoreGraphics

struct InputMonitoringPermissionManager {
    func isGranted() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Triggers the system permission prompt if not yet granted.
    func requestIfNeeded() {
        guard !isGranted() else { return }
        CGRequestListenEventAccess()
    }

    func openSettings() {
        let url: URL
        if #available(macOS 13, *) {
            url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent")!
        } else {
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        }
        NSWorkspace.shared.open(url)
    }
}

import AppKit
import SwiftUI

class MenubarManager: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private weak var orchestrator: FixOrchestrator?
    let statusIconAnimator: StatusIconAnimator
    private let openSettingsAction: () -> Void

    private var enableMenuItem: NSMenuItem?

    init(settings: AppSettings, orchestrator: FixOrchestrator, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.orchestrator = orchestrator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusIconAnimator = StatusIconAnimator(statusItem: statusItem)
        self.openSettingsAction = openSettings

        super.init()

        let icon = StatusIconAnimator.defaultIcon()
        statusItem.button?.image = icon
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let enableItem = NSMenuItem(
            title: "Enable LayoutFixer",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = settings.isEnabled ? .on : .off
        self.enableMenuItem = enableItem
        menu.addItem(enableItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let accessibilityItem = NSMenuItem(
            title: "Accessibility Permissions",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let inputMonitoringItem = NSMenuItem(
            title: "Input Monitoring Permissions",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        inputMonitoringItem.target = self
        menu.addItem(inputMonitoringItem)

        menu.addItem(.separator())

        let exportLogsItem = NSMenuItem(title: "Export Logs", action: nil, keyEquivalent: "")
        let exportSubmenu = NSMenu(title: "Export Logs")
        for range in LogExporter.timeRanges {
            let item = NSMenuItem(title: range.title, action: #selector(exportLogs(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = range.since.map { $0 as NSDate }
            exportSubmenu.addItem(item)
        }
        exportLogsItem.submenu = exportSubmenu
        menu.addItem(exportLogsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About LayoutFixer",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit LayoutFixer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        enableMenuItem?.state = settings.isEnabled ? .on : .off
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        enableMenuItem?.state = settings.isEnabled ? .on : .off
    }

    @objc private func openSettings() {
        openSettingsAction()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openInputMonitoringSettings() {
        InputMonitoringPermissionManager().openSettings()
    }

    @objc private func exportLogs(_ sender: NSMenuItem) {
        let since = (sender.representedObject as? NSDate) as Date?
        LogExporter.shared.promptAndExport(since: since)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

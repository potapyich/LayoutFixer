import AppKit
import OSLog

class LogExporter {
    static let shared = LogExporter()

    private let subsystem = "com.potapyich.LayoutFixer"

    enum TimeRange {
        case minutes(Int)
        case hours(Int)
        case all

        var title: String {
            switch self {
            case .minutes(let n): return "Last \(n) Minute\(n == 1 ? "" : "s")"
            case .hours(let n):   return "Last \(n) Hour\(n == 1 ? "" : "s")"
            case .all:            return "All Available"
            }
        }

        var since: Date? {
            switch self {
            case .minutes(let n): return Date(timeIntervalSinceNow: -Double(n) * 60)
            case .hours(let n):   return Date(timeIntervalSinceNow: -Double(n) * 3600)
            case .all:            return nil
            }
        }
    }

    static let timeRanges: [TimeRange] = [
        .minutes(5),
        .minutes(15),
        .minutes(30),
        .hours(1),
        .hours(24),
        .all
    ]

    // MARK: - Export

    func exportedText(since date: Date?) throws -> String {
        let store = try OSLogStore(scope: .currentProcessIdentifier)

        let position: OSLogPosition
        if let date {
            position = store.position(date: date)
        } else {
            position = store.position(timeIntervalSinceLatestBoot: 0)
        }

        let entries = try store.getEntries(
            at: position,
            matching: NSPredicate(format: "subsystem == %@", subsystem)
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var lines: [String] = [
            "LayoutFixer Log Export",
            "Exported : \(formatter.string(from: Date()))",
            "From     : \(date.map { formatter.string(from: $0) } ?? "all available")",
            "Subsystem: \(subsystem)",
            String(repeating: "-", count: 72),
            ""
        ]

        var count = 0
        for entry in entries {
            guard let log = entry as? OSLogEntryLog else { continue }
            let level = levelTag(log.level)
            let line = "[\(formatter.string(from: log.date))] \(level) [\(log.category)] \(log.composedMessage)"
            lines.append(line)
            count += 1
        }

        if count == 0 {
            lines.append("(no log entries found for this time range)")
        }

        return lines.joined(separator: "\n")
    }

    func promptAndExport(since date: Date?) {
        let panel = NSSavePanel()
        let nameFormatter = DateFormatter()
        nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        nameFormatter.locale = Locale(identifier: "en_US_POSIX")
        panel.nameFieldStringValue = "LayoutFixer_\(nameFormatter.string(from: Date())).log"
        panel.allowedContentTypes = [.plainText]
        panel.title = "Export LayoutFixer Logs"
        panel.prompt = "Export"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try exportedText(since: date)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    // MARK: - Private

    private func levelTag(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug:     return "[DEBUG]"
        case .info:      return "[INFO] "
        case .notice:    return "[NOTE] "
        case .error:     return "[ERROR]"
        case .fault:     return "[FAULT]"
        default:         return "[     ]"
        }
    }
}

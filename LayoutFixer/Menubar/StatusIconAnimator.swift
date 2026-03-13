import AppKit

class StatusIconAnimator {
    private weak var statusItem: NSStatusItem?
    private var pendingTask: DispatchWorkItem?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    /// Shows the target layout's flag, blinks once, then restores the default icon.
    func animateSuccess(targetLayout: LayoutInfo) {
        pendingTask?.cancel()

        let flagImage    = Self.flagImage(emoji: targetLayout.flag)
        let defaultImage = Self.defaultIcon()

        statusItem?.button?.image = flagImage

        let final = DispatchWorkItem { [weak self] in
            self?.statusItem?.button?.image = defaultImage
            self?.pendingTask = nil
        }
        pendingTask = final
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: final)
    }

    // MARK: - Icon helpers

    static func defaultIcon() -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "LayoutFixer")?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = true
        return img ?? NSImage()
    }

    static func flagImage(emoji: String) -> NSImage {
        let size: CGFloat = 18
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size * 0.85)]
        let textSize = (emoji as NSString).size(withAttributes: attrs)
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            (emoji as NSString).draw(
                at: NSPoint(x: (rect.width  - textSize.width)  / 2,
                            y: (rect.height - textSize.height) / 2),
                withAttributes: attrs
            )
            return true
        }
    }


}

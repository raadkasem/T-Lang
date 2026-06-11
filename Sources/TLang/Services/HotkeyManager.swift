import AppKit

extension NSEvent {
    /// Layout-independent key for ⌘-shortcut matching. On non-Latin layouts
    /// (e.g. Arabic) charactersIgnoringModifiers returns the native glyph
    /// ("ش" on the A key), while `characters` resolves through the
    /// ASCII-capable layout when ⌘ is held — so check both.
    var shortcutKey: String? {
        if let c = charactersIgnoringModifiers?.lowercased(),
           c.first?.isASCII == true {
            return c
        }
        return characters?.lowercased()
    }
}

/// Detects a quick double press of ⌘C system-wide (hold ⌘, tap C twice).
/// Requires the app to be trusted under Privacy & Security → Accessibility.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onDoubleCopy: (() -> Void)?

    private var monitor: Any?
    private var lastPress: TimeInterval = 0
    private let doublePressWindow: TimeInterval = 0.5

    var isRunning: Bool { monitor != nil }

    private init() {}

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            Task { @MainActor in
                HotkeyManager.shared.handle(event)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.shortcutKey == "c",
              event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.command]
        else { return }

        let now = event.timestamp
        if now - lastPress < doublePressWindow {
            lastPress = 0
            onDoubleCopy?()
        } else {
            lastPress = now
        }
    }
}

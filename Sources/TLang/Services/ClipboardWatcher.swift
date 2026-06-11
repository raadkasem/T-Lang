import AppKit

/// Polls NSPasteboard for changes while enabled; delivers newly-copied text.
@MainActor
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    var onText: ((String) -> Void)?

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var ignoredChangeCounts = Set<Int>()
    private let maxLength = 20_000

    var isRunning: Bool { timer != nil }

    private init() {}

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                ClipboardWatcher.shared.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call right after this app writes to the pasteboard so the watcher
    /// doesn't translate its own output.
    func markSelfWrite() {
        ignoredChangeCounts.insert(NSPasteboard.general.changeCount)
    }

    /// Swallow the current pasteboard change (used by the hotkey flow, which
    /// handles the copied text itself via the floating panel).
    func suppressCurrentChange() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func tick() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if ignoredChangeCounts.remove(count) != nil { return }
        // Ignore copies made inside TLang itself.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier
            == ProcessInfo.processInfo.processIdentifier { return }

        guard let text = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text.count <= maxLength,
              Self.looksTranslatable(text)
        else { return }

        onText?(text)
    }

    /// Skip clipboard content that is clearly not prose — URLs, emails,
    /// numbers, API keys/tokens — so copying config values doesn't trigger
    /// pointless translations.
    static func looksTranslatable(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        let isSingleToken = !text.contains(where: { $0.isWhitespace })
        guard isSingleToken else { return true }

        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://")
            || lower.hasPrefix("file://") || lower.hasPrefix("ftp://") {
            return false
        }
        if text.contains("@") && text.contains(".") { return false }
        if Double(text.replacingOccurrences(of: ",", with: "")) != nil { return false }
        // A single unbroken token this long is a key/token/hash, not a word.
        if text.count > 30 { return false }
        return true
    }
}

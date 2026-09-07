import AppKit
import Foundation

/// Append-only log of failed API requests at
/// `~/Library/Application Support/TLang/error.log`, capped in size.
/// The error UI links here so the full technical detail (raw server body,
/// URLs, timestamps) survives after the on-screen banner is gone.
enum ErrorLog {
    static var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TLang", isDirectory: true)
        return dir.appendingPathComponent("error.log")
    }

    /// Trim to half of this size so one huge response body can't grow the
    /// file without bound.
    private static let maxBytes = 262_144

    /// Stream and alternatives failures can race; keep appends atomic.
    private static let lock = NSLock()

    static func record(model: String, endpoint: String, error: Error) {
        let entry = """
        \(timestamp()) — model=\(model) — endpoint=\(endpoint)
        \(detailText(for: error))

        ────

        """
        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            try trimIfNeeded()
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(entry.utf8))
        } catch {
            // A failing logger must never mask the error it is reporting.
        }
    }

    /// Opens the log in the user's default text editor (creating it first
    /// so the reveal always works).
    static func open() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("No errors recorded yet.\n".utf8))
        }
        NSWorkspace.shared.open(fileURL)
    }

    /// The full technical text for one error, mirroring what the UI's
    /// Details disclosure shows.
    static func detailText(for error: Error) -> String {
        var text = TranslationError.technicalDetail(for: error)
            ?? String(describing: error)
        if let summary = (error as? LocalizedError)?.errorDescription,
           let detail = TranslationError.technicalDetail(for: error),
           !summary.isEmpty, !detail.contains(summary) {
            text = summary + "\n\n" + detail
        }
        return text
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func trimIfNeeded() throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let size = attrs[.size] as? Int ?? 0
        guard size > maxBytes, let data = try? Data(contentsOf: fileURL) else { return }
        try data.suffix(maxBytes / 2).write(to: fileURL)
    }
}

import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let source: String
    let translation: String
    let direction: Direction
    var pinned: Bool

    init(source: String, translation: String, direction: Direction) {
        self.id = UUID()
        self.date = Date()
        self.source = source
        self.translation = translation
        self.direction = direction
        self.pinned = false
    }
}

/// Persists translation history to ~/Library/Application Support/TLang/history.json.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private let maxEntries = 500

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TLang", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func add(source: String, translation: String, direction: Direction) {
        guard AppSettings.shared.saveHistory else { return }
        if let last = entries.first(where: { !$0.pinned }) ?? entries.first,
           last.source == source, last.translation == translation {
            return
        }
        entries.insert(HistoryEntry(source: source, translation: translation, direction: direction), at: 0)
        trim()
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].pinned.toggle()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        scheduleSave()
    }

    func clearAll(keepPinned: Bool = true) {
        if keepPinned {
            entries.removeAll { !$0.pinned }
        } else {
            entries.removeAll()
        }
        scheduleSave()
    }

    private func trim() {
        guard entries.count > maxEntries else { return }
        // Drop oldest unpinned entries first.
        var excess = entries.count - maxEntries
        for i in stride(from: entries.count - 1, through: 0, by: -1) where excess > 0 {
            if !entries[i].pinned {
                entries.remove(at: i)
                excess -= 1
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([HistoryEntry].self, from: data) {
            entries = loaded
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

import SwiftUI

struct HistorySidebar: View {
    @EnvironmentObject var history: HistoryStore
    @State private var query = ""
    var onSelect: (HistoryEntry) -> Void

    private var filtered: [HistoryEntry] {
        let base = history.entries.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.date > $1.date
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.source.localizedCaseInsensitiveContains(q)
                || $0.translation.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !history.entries.isEmpty {
                    Button("Clear") {
                        history.clearAll(keepPinned: true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .help("Remove all unpinned entries")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                TextField("Search history", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(history.entries.isEmpty ? "No translations yet" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { entry in
                            HistoryRow(entry: entry, onSelect: onSelect)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    @EnvironmentObject var history: HistoryStore
    let entry: HistoryEntry
    var onSelect: (HistoryEntry) -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.direction == .enToAr ? "EN → AR" : "AR → EN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary.opacity(0.6)))
                    if entry.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(entry.date, format: .relative(presentation: .named))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Text(entry.source)
                    .font(.system(size: 12))
                    .lineLimit(2)
                Text(entry.translation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.025))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(entry.pinned ? "Unpin" : "Pin") {
                history.togglePin(entry.id)
            }
            Button("Copy Translation") {
                PasteService.copyToClipboard(entry.translation)
            }
            Divider()
            Button("Delete", role: .destructive) {
                history.delete(entry.id)
            }
        }
    }
}

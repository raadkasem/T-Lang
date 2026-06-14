import SwiftUI

struct HistorySidebar: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var settings: AppSettings
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
                UppercaseLabel(settings.tr("History"))
                Spacer()
                if !history.entries.isEmpty {
                    Button(settings.tr("Clear")) {
                        history.clearAll(keepPinned: true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .help(settings.tr("Remove all unpinned entries"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                TextField(settings.tr("Search history"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.textTertiary)
                    Text(settings.tr(history.entries.isEmpty ? "No translations yet" : "No matches"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
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
    @EnvironmentObject var settings: AppSettings
    let entry: HistoryEntry
    var onSelect: (HistoryEntry) -> Void
    @State private var hovering = false

    private var chipColor: Color {
        Theme.languageColor(isArabic: entry.direction == .arToEn)
    }

    var body: some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.direction == .enToAr ? "EN → AR" : "AR → EN")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(chipColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(chipColor.opacity(0.13)))
                    if entry.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.gold)
                    }
                    Spacer()
                    Text(entry.date, format: .relative(presentation: .named))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(entry.source)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(entry.translation)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? Theme.cardHover : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hovering ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(settings.tr(entry.pinned ? "Unpin" : "Pin")) {
                history.togglePin(entry.id)
            }
            Button(settings.tr("Copy Translation")) {
                PasteService.copyToClipboard(entry.translation)
            }
            Divider()
            Button(settings.tr("Delete"), role: .destructive) {
                history.delete(entry.id)
            }
        }
    }
}

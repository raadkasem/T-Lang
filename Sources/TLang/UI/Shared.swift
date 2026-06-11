import AppKit
import SwiftUI

/// Copy button that briefly flips to a checkmark.
struct CopyButton: View {
    let text: String
    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        Button {
            guard !text.isEmpty else { return }
            PasteService.copyToClipboard(text)
            withAnimation(.easeInOut(duration: 0.15)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(copied ? Theme.green : (hovering ? Theme.textPrimary : Theme.textTertiary))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Copy")
        .disabled(text.isEmpty)
    }
}

/// Small native spinner shown while streaming. Uses NSProgressIndicator under
/// the hood — SwiftUI repeatForever animations burn CPU when views re-render.
struct StreamingIndicator: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .tint(Theme.gold)
    }
}

/// Language chips joined by the lapis→gold gradient arrow.
/// English is always lapis; Arabic is always gold.
struct DirectionPill: View {
    let direction: Direction
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            chip(direction.sourceName, isArabic: direction == .arToEn)
            Image(systemName: "arrow.right")
                .font(.system(size: compact ? 8 : 9, weight: .black))
                .foregroundStyle(Theme.accentGradient)
            chip(direction.targetName, isArabic: direction == .enToAr)
        }
        .animation(.easeInOut(duration: 0.2), value: direction)
    }

    private func chip(_ name: String, isArabic: Bool) -> some View {
        let color = Theme.languageColor(isArabic: isArabic)
        return Text(name)
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 3 : 4)
            .background(Capsule().fill(color.opacity(0.13)))
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

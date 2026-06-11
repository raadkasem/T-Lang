import AppKit
import SwiftUI

/// Frosted window background.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

/// Copy button that briefly flips to a checkmark.
struct CopyButton: View {
    let text: String
    @State private var copied = false

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
                .foregroundStyle(copied ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
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
    }
}

/// Capsule showing the live translation direction.
struct DirectionPill: View {
    let direction: Direction

    var body: some View {
        HStack(spacing: 8) {
            Text(direction.sourceName)
                .fontWeight(.medium)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(direction.targetName)
                .fontWeight(.medium)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(.quaternary.opacity(0.6)))
        .animation(.easeInOut(duration: 0.2), value: direction)
    }
}

import AppKit
import SwiftUI

/// Non-activating floating panel shown near the cursor on double ⌘C.
@MainActor
final class FloatingPanelController {
    static let shared = FloatingPanelController()

    private var panel: NSPanel?
    private var globalClickMonitor: Any?
    private var localMonitor: Any?
    private var autoCloseWorkItem: DispatchWorkItem?

    private let panelSize = NSSize(width: 420, height: 280)

    private init() {}

    func handleDoubleCopy() {
        ClipboardWatcher.shared.suppressCurrentChange()
        // Give the source app a beat to finish writing the copy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            ClipboardWatcher.shared.suppressCurrentChange()
            guard let text = NSPasteboard.general.string(forType: .string)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { return }

            show()
            let vm = TranslatorViewModel.panel
            vm.setTexts(source: text, output: "")
            vm.translateNow { final in
                guard !final.isEmpty else { return }
                if AppSettings.shared.replaceInPlace {
                    PasteService.pasteIntoFrontApp(final)
                    self.scheduleAutoClose(after: 0.9)
                }
            }
        }
    }

    func show() {
        autoCloseWorkItem?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x + 14, y: mouse.y - panelSize.height - 14)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            let visible = screen.visibleFrame
            origin.x = min(max(visible.minX + 8, origin.x), visible.maxX - panelSize.width - 8)
            origin.y = min(max(visible.minY + 8, origin.y), visible.maxY - panelSize.height - 8)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        installMonitors()
    }

    func close() {
        autoCloseWorkItem?.cancel()
        TranslatorViewModel.panel.stop()
        panel?.orderOut(nil)
        removeMonitors()
    }

    func openInMainWindow() {
        let panelVM = TranslatorViewModel.panel
        TranslatorViewModel.main.setTexts(
            source: panelVM.sourceText,
            output: panelVM.outputText,
            direction: panelVM.direction
        )
        close()
        AppDelegate.shared?.openMainWindow()
    }

    private func scheduleAutoClose(after delay: TimeInterval) {
        autoCloseWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.close()
        }
        autoCloseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(
            rootView: FloatingPanelView(vm: TranslatorViewModel.panel)
                .environmentObject(AppSettings.shared)
        )
        return panel
    }

    private func installMonitors() {
        removeMonitors()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            Task { @MainActor in
                FloatingPanelController.shared.close()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { event in
            Task { @MainActor in
                let controller = FloatingPanelController.shared
                if event.type == .keyDown {
                    if event.keyCode == 53 { // Escape
                        controller.close()
                    }
                } else if event.window !== controller.panel {
                    controller.close()
                }
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}

struct FloatingPanelView: View {
    @ObservedObject var vm: TranslatorViewModel
    @EnvironmentObject var settings: AppSettings

    private var isRTL: Bool { vm.direction.targetIsRTL }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                LogoMark(size: 18)
                DirectionPill(direction: vm.direction, compact: true)
                if vm.isTranslating {
                    if vm.isThinkingPhase {
                        Text(settings.tr("thinking…"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    StreamingIndicator()
                }
                Spacer()
                Button {
                    FloatingPanelController.shared.close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(settings.tr("Close (Esc)"))
            }
            .padding(.horizontal, 13)
            .padding(.top, 11)
            .padding(.bottom, 9)

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.horizontal, 13)

            ScrollView {
                Group {
                    if let error = vm.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.coral)
                    } else if vm.outputText.isEmpty && vm.isTranslating {
                        Text(settings.tr("Translating…"))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Text(vm.outputText)
                            .font(.system(size: 14))
                            .lineSpacing(3)
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(isRTL ? .trailing : .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .padding(13)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.horizontal, 13)

            HStack(spacing: 8) {
                SpeakerButton(text: vm.outputText, isArabic: isRTL, id: "panel")
                CopyButton(text: vm.outputText)
                Button {
                    PasteService.pasteIntoFrontApp(vm.outputText)
                    FloatingPanelController.shared.close()
                } label: {
                    Label(settings.tr("Replace"), systemImage: "arrow.uturn.backward.square")
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.gold))
                .help(settings.tr("Paste the translation over the original selection"))
                .disabled(vm.outputText.isEmpty)
                Spacer()
                Button {
                    FloatingPanelController.shared.openInMainWindow()
                } label: {
                    Label(settings.tr("Open in TLang"), systemImage: "macwindow")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
        }
        .frame(width: 420, height: 280)
        .modifier(PanelChrome())
        .tint(Theme.lapis)
        .environment(\.layoutDirection, settings.uiLayoutDirection)
    }
}

/// Panel surface: Liquid Glass on macOS 26+, translucent ink/paper otherwise.
private struct PanelChrome: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(shape.strokeBorder(Theme.borderGradient, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 22, y: 8)
        } else {
            content
                .background(shape.fill(Theme.ink.opacity(0.98)))
                .overlay(shape.strokeBorder(Theme.borderGradient, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 22, y: 8)
        }
    }
}

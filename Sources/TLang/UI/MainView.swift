import SwiftUI

struct MainView: View {
    @ObservedObject var vm = TranslatorViewModel.main
    @EnvironmentObject var settings: AppSettings
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                translator
                if showHistory {
                    Divider()
                    HistorySidebar { entry in
                        vm.setTexts(
                            source: entry.source,
                            output: entry.translation,
                            direction: entry.direction
                        )
                    }
                    .frame(width: 300)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 720, minHeight: 440)
        .background(VisualEffectBackground().ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: showHistory)
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Leave room for traffic lights in the transparent title bar.
            Spacer().frame(width: 66)
            Text("TLang")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            DirectionPill(direction: vm.direction)
            Spacer()
            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(showHistory ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Translation history")
            Button {
                AppDelegate.shared?.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .font(.system(size: 14))
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var translator: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                EditorCard(
                    title: vm.direction.sourceName,
                    text: $vm.sourceText,
                    isRTL: vm.direction.sourceIsRTL,
                    placeholder: "Type or paste text — or just copy text anywhere",
                    onClear: { vm.clear() }
                )

                Button {
                    vm.swap()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.quaternary.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .help("Swap — translate the result back")
                .disabled(vm.outputText.isEmpty)

                OutputCard(vm: vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Toggle("Auto-translate", isOn: $settings.autoTranslate)
                .toggleStyle(.switch)
                .controlSize(.mini)
            Toggle("Watch clipboard", isOn: $settings.clipboardWatcher)
                .toggleStyle(.switch)
                .controlSize(.mini)
            Spacer()
            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(error)
            }
            if vm.isTranslating {
                Button {
                    vm.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
                .buttonStyle(.bordered)
            } else {
                Button {
                    vm.translateNow()
                } label: {
                    Label("Translate", systemImage: "sparkles")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}

struct EditorCard: View {
    let title: String
    @Binding var text: String
    let isRTL: Bool
    var placeholder = ""
    var onClear: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !text.isEmpty {
                    Text("\(text.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Button {
                        onClear?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ZStack(alignment: isRTL ? .topTrailing : .topLeading) {
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 7)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct OutputCard: View {
    @ObservedObject var vm: TranslatorViewModel

    private var isRTL: Bool { vm.direction.targetIsRTL }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vm.direction.targetName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if vm.isTranslating {
                    if vm.isThinkingPhase {
                        Text("thinking…")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    StreamingIndicator()
                }
                CopyButton(text: vm.outputText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ZStack(alignment: isRTL ? .topTrailing : .topLeading) {
                if vm.outputText.isEmpty {
                    Text(vm.isTranslating ? "Translating…" : "Translation appears here")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
                // Read-only TextEditor (constant binding) so ⌘A/⌘C and native
                // selection work in the output pane too.
                TextEditor(text: .constant(vm.outputText))
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 7)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

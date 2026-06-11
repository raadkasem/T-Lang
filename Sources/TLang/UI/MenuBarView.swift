import SwiftUI

struct MenuBarView: View {
    @ObservedObject var vm = TranslatorViewModel.main
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            header

            EditorCard(
                title: vm.direction.sourceName,
                text: $vm.sourceText,
                isRTL: vm.direction.sourceIsRTL,
                placeholder: "Type, paste, or copy text anywhere",
                onClear: { vm.clear() }
            )
            .frame(height: 110)

            HStack {
                DirectionPill(direction: vm.direction)
                Spacer()
                Button {
                    vm.swap()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Swap")
                .disabled(vm.outputText.isEmpty)
            }

            OutputCard(vm: vm)
                .frame(minHeight: 130)

            footer
        }
        .padding(12)
        .frame(width: 360, height: 420)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("TLang")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                dismiss()
                AppDelegate.shared?.openMainWindow()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Open main window")
            Button {
                dismiss()
                AppDelegate.shared?.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit TLang")
        }
        .font(.system(size: 12))
    }

    private var footer: some View {
        HStack {
            Toggle("Clipboard", isOn: $settings.clipboardWatcher)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help("Auto-translate copied text")
            Spacer()
            if let error = vm.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .help(error)
            }
            if vm.isTranslating {
                Button("Stop") {
                    vm.stop()
                }
                .keyboardShortcut(".", modifiers: .command)
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Translate") {
                    vm.translateNow()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(.system(size: 11))
    }
}

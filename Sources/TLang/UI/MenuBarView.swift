import SwiftUI

struct MenuBarView: View {
    @ObservedObject var vm = TranslatorViewModel.main
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                header

                EditorCard(
                    title: vm.direction.sourceName,
                    accent: Theme.languageColor(isArabic: vm.direction == .arToEn),
                    text: $vm.sourceText,
                    isRTL: vm.direction.sourceIsRTL,
                    placeholder: "Type, paste, or copy text anywhere",
                    onClear: { vm.clear() },
                    dictationVM: vm
                )
                .frame(height: 108)

                HStack {
                    DirectionPill(direction: vm.direction, compact: true)
                    Spacer()
                    SwapButton(disabled: vm.outputText.isEmpty) {
                        vm.swap()
                    }
                    .scaleEffect(0.8)
                }

                OutputCard(vm: vm)
                    .frame(minHeight: 128)

                footer
            }
            .padding(12)
        }
        .frame(width: 360, height: 430)
        .tint(Theme.lapis)
        .environment(\.layoutDirection, settings.uiLayoutDirection)
    }

    private var header: some View {
        HStack(spacing: 8) {
            LogoMark(size: 20)
            Text("TLang")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            IconButton(systemImage: "macwindow", help: settings.tr("Open main window")) {
                dismiss()
                AppDelegate.shared?.openMainWindow()
            }
            IconButton(systemImage: "gearshape", help: settings.tr("Settings")) {
                dismiss()
                AppDelegate.shared?.openSettingsWindow()
            }
            IconButton(systemImage: "power", help: settings.tr("Quit TLang")) {
                NSApp.terminate(nil)
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle(settings.tr("Watch clipboard"), isOn: $settings.clipboardWatcher)
                .toggleStyle(PillToggleStyle(tint: Theme.gold))
            Spacer()
            if let error = vm.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.coral)
                    .help(error)
            }
            if vm.isTranslating {
                Button(settings.tr("Stop")) {
                    vm.stop()
                }
                .keyboardShortcut(".", modifiers: .command)
                .buttonStyle(DangerButtonStyle())
            } else {
                Button(settings.tr("Translate")) {
                    vm.translateNow()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(GradientButtonStyle())
                .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

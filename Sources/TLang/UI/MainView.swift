import SwiftUI

struct MainView: View {
    @ObservedObject var vm = TranslatorViewModel.main
    @EnvironmentObject var settings: AppSettings
    @State private var showHistory = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                HStack(spacing: 0) {
                    translator
                    if showHistory {
                        Rectangle()
                            .fill(Theme.stroke)
                            .frame(width: 1)
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
        }
        .frame(minWidth: 720, minHeight: 440)
        .animation(.easeInOut(duration: 0.2), value: showHistory)
        .tint(Theme.lapis)
        .environment(\.layoutDirection, settings.uiLayoutDirection)
    }

    private var header: some View {
        HStack(spacing: 10) {
            // Leave room for traffic lights in the transparent title bar.
            Spacer().frame(width: 62)
            LogoMark(size: 22)
            Text("TLang")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            DirectionPill(direction: vm.direction)
            Spacer()
            LanguageSwitcher()
            IconButton(
                systemImage: settings.appearance.icon,
                help: String(format: settings.tr("Appearance: %@ — click to switch"), settings.tr(settings.appearance.label))
            ) {
                settings.appearance = settings.appearance.next
            }
            IconButton(
                systemImage: "clock.arrow.circlepath",
                active: showHistory,
                help: settings.tr("Translation history")
            ) {
                showHistory.toggle()
            }
            IconButton(systemImage: "gearshape", help: settings.tr("Settings")) {
                AppDelegate.shared?.openSettingsWindow()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        // Keep window-control spacing on the physical left regardless of UI language.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var translator: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                EditorCard(
                    title: vm.direction.sourceName,
                    accent: Theme.languageColor(isArabic: vm.direction == .arToEn),
                    text: $vm.sourceText,
                    isRTL: vm.direction.sourceIsRTL,
                    placeholder: settings.tr("Type or paste — or just copy text anywhere"),
                    onClear: { vm.clear() },
                    dictationVM: vm
                )

                SwapButton(disabled: vm.outputText.isEmpty) {
                    vm.swap()
                }

                OutputCard(vm: vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Toggle(settings.tr("Auto-translate"), isOn: $settings.autoTranslate)
                .toggleStyle(PillToggleStyle())
            Toggle(settings.tr("Watch clipboard"), isOn: $settings.clipboardWatcher)
                .toggleStyle(PillToggleStyle(tint: Theme.gold))
            Spacer()
            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.coral)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 300, alignment: .trailing)
                    .help(error)
            }
            if vm.isTranslating {
                Button {
                    vm.stop()
                } label: {
                    Label(settings.tr("Stop"), systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
                .buttonStyle(DangerButtonStyle())
            } else {
                Button {
                    vm.translateNow()
                } label: {
                    Label(settings.tr("Translate"), systemImage: "sparkles")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(GradientButtonStyle())
                .disabled(vm.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}

struct SwapButton: View {
    var disabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(disabled ? AnyShapeStyle(Theme.textTertiary) : AnyShapeStyle(Theme.accentGradient))
                .frame(width: 32, height: 32)
                .background(Circle().fill(hovering && !disabled ? Theme.cardHover : Theme.field))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Swap — translate the result back")
        .disabled(disabled)
    }
}

struct EditorCard: View {
    let title: String
    let accent: Color
    @Binding var text: String
    let isRTL: Bool
    var placeholder = ""
    var onClear: (() -> Void)?
    var dictationVM: TranslatorViewModel?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
                Spacer()
                if let dictationVM {
                    MicButton(vm: dictationVM, accent: accent)
                }
                if !text.isEmpty {
                    Text("\(text.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                    SpeakerButton(text: text, isArabic: isRTL, id: "source")
                    ClearButton { onClear?() }
                }
            }
            .padding(.horizontal, 13)
            .padding(.top, 11)
            .padding(.bottom, 6)

            ZStack(alignment: isRTL ? .topTrailing : .topLeading) {
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .focused($focused)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            }
        }
        .glassCard(focus: focused ? accent : nil)
    }
}

struct OutputCard: View {
    @ObservedObject var vm: TranslatorViewModel
    @EnvironmentObject var settings: AppSettings

    private var isRTL: Bool { vm.direction.targetIsRTL }
    private var accent: Color { Theme.languageColor(isArabic: vm.direction == .enToAr) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                Text(vm.direction.targetName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.95))
                Spacer()
                if vm.isTranslating {
                    if vm.retryAttempt > 0 {
                        Text(settings.tr("retrying…"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.coral)
                    } else if vm.isThinkingPhase {
                        Text(settings.tr("thinking…"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    StreamingIndicator()
                }
                if !vm.outputText.isEmpty {
                    SpeakerButton(text: vm.displayedText, isArabic: isRTL, id: "output")
                }
                CopyButton(text: vm.displayedText)
            }
            .padding(.horizontal, 13)
            .padding(.top, 11)
            .padding(.bottom, 6)

            ZStack(alignment: isRTL ? .topTrailing : .topLeading) {
                if vm.outputText.isEmpty {
                    Text(settings.tr(vm.isTranslating ? "Translating…" : "Translation appears here"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 13)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
                // Read-only TextEditor (constant binding) so ⌘A/⌘C and native
                // selection work in the output pane too.
                TextEditor(text: .constant(vm.displayedText))
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            }

            VariantBar(vm: vm)
        }
        .glassCard(focus: vm.isTranslating ? accent : nil)
    }
}

/// Footer of the output card: offers / pages between alternative phrasings.
struct VariantBar: View {
    @ObservedObject var vm: TranslatorViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            if vm.loadingAlternatives {
                HStack(spacing: 6) {
                    StreamingIndicator()
                    Text(settings.tr("finding alternatives…"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
            } else if vm.totalVariants > 1 {
                HStack(spacing: 10) {
                    pageButton("chevron.left") { vm.showVariant(vm.variantIndex - 1) }
                        .disabled(vm.variantIndex == 0)
                    Text(vm.variantIndex == 0
                         ? settings.tr("Original")
                         : "\(settings.tr("Alternatives")) \(vm.variantIndex)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minWidth: 92)
                    pageButton("chevron.right") { vm.showVariant(vm.variantIndex + 1) }
                        .disabled(vm.variantIndex >= vm.totalVariants - 1)
                    Spacer()
                    Text("\(vm.variantIndex + 1) / \(vm.totalVariants)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            } else if vm.canLoadAlternatives {
                Button {
                    vm.loadAlternatives()
                } label: {
                    Label(settings.tr("Alternatives"), systemImage: "wand.and.stars")
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.gold))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, vm.canLoadAlternatives || vm.totalVariants > 1 || vm.loadingAlternatives ? 9 : 0)
    }

    private func pageButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

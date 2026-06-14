import AppKit
import SwiftUI

/// Shared circular chrome for the small action buttons in pane headers, so
/// they read as tappable controls rather than faint glyphs.
struct CardIconChrome: ViewModifier {
    var active: Bool = false
    var activeColor: Color = Theme.lapis
    var hovering: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(active ? activeColor.opacity(0.18) : (hovering ? Theme.cardHover : Theme.field))
            )
            .overlay(
                Circle().strokeBorder(active ? activeColor.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Circle())
    }
}

extension View {
    func cardIconChrome(active: Bool = false, activeColor: Color = Theme.lapis, hovering: Bool = false) -> some View {
        modifier(CardIconChrome(active: active, activeColor: activeColor, hovering: hovering))
    }
}

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
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(copied ? Theme.green : (hovering ? Theme.textPrimary : Theme.textSecondary))
                .contentTransition(.symbolEffect(.replace))
                .cardIconChrome(active: copied, activeColor: Theme.green, hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Copy")
        .disabled(text.isEmpty)
    }
}

/// Speaker button: reads the pane's text aloud in its language's voice.
/// Animated while speaking; click again to stop.
struct SpeakerButton: View {
    let text: String
    let isArabic: Bool
    let id: String
    @ObservedObject private var speech = SpeechService.shared
    @State private var hovering = false

    private var speaking: Bool { speech.speakingID == id }
    private var tint: Color { Theme.languageColor(isArabic: isArabic) }

    var body: some View {
        Button {
            speech.toggle(text: text, isArabic: isArabic, id: id)
        } label: {
            Image(systemName: speaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(speaking ? tint : (hovering ? Theme.textPrimary : Theme.textSecondary))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: speaking)
                .cardIconChrome(active: speaking, activeColor: tint, hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(speaking ? "Stop speaking" : "Speak aloud")
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

/// Clear button for an editor pane.
struct ClearButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hovering ? Theme.coral : Theme.textSecondary)
                .cardIconChrome(active: hovering, activeColor: Theme.coral, hovering: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Clear")
    }
}

/// Compact flag switcher for the UI language. Tapping a flag sets the language
/// explicitly (English / Arabic). "Auto" remains available in Settings.
struct LanguageSwitcher: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 2) {
            flag("🇬🇧", language: .english)
            flag("🇸🇦", language: .arabic)
        }
        .padding(2)
        .background(Capsule().fill(Theme.field))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        // Keep flag order stable regardless of UI direction.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func flag(_ emoji: String, language: AppLanguage) -> some View {
        let active = settings.resolvedLanguage == Localizer.resolve(language)
        return Button {
            settings.uiLanguage = language
        } label: {
            Text(emoji)
                .font(.system(size: 13))
                .saturation(active ? 1 : 0)
                .opacity(active ? 1 : 0.55)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(active ? Theme.cardHover : .clear))
                .overlay(Capsule().strokeBorder(active ? Theme.strokeStrong : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(language.label)
    }
}

/// Microphone dictation toggle for the source pane. While listening it turns
/// solid red with an expanding pulse ring so it's obvious recording is live.
struct MicButton: View {
    @ObservedObject var vm: TranslatorViewModel
    @ObservedObject private var dictation = DictationService.shared
    let accent: Color
    @State private var hovering = false
    @State private var pulse = false

    private var listening: Bool { dictation.isListening }
    private var hasError: Bool { dictation.errorMessage != nil && !listening }

    var body: some View {
        Button {
            vm.toggleDictation()
        } label: {
            ZStack {
                if listening {
                    Circle()
                        .stroke(Theme.coral, lineWidth: 2)
                        .frame(width: 26, height: 26)
                        .scaleEffect(pulse ? 1.7 : 1.0)
                        .opacity(pulse ? 0 : 0.8)
                }
                Image(systemName: listening ? "mic.fill" : "mic")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(listening ? .white : (hasError ? Theme.coral : (hovering ? Theme.textPrimary : Theme.textSecondary)))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(listening ? Theme.coral : (hovering ? Theme.cardHover : Theme.field)))
                    .overlay(Circle().strokeBorder(listening ? Theme.coral : Theme.stroke, lineWidth: 1))
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(dictation.errorMessage ?? (listening ? "Stop dictation" : "Dictate"))
        .onChange(of: listening) { _, now in
            if now {
                pulse = false
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { pulse = true }
            } else {
                pulse = false
            }
        }
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

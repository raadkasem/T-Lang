import SwiftUI

struct SettingsView: View {
    enum Tab: String, CaseIterable {
        case provider = "Provider"
        case behavior = "Behavior"
        case about = "About"

        var icon: String {
            switch self {
            case .provider: return "server.rack"
            case .behavior: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }

    @State private var tab: Tab = .provider

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                tabBar
                    .padding(.top, 36)
                Group {
                    switch tab {
                    case .provider: ProviderSettingsTab()
                    case .behavior: BehaviorSettingsTab()
                    case .about: AboutTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 560, height: 560)
        .tint(Theme.lapis)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { item in
                let selected = tab == item
                Button {
                    tab = item
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Theme.textPrimary : Theme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected ? Theme.cardHover : .clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(selected ? Theme.strokeStrong : .clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.field))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - Building blocks

private struct SettingsCard<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UppercaseLabel(title)
            content
            if let footer {
                Text(footer)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard()
    }
}

private struct ThemedField: View {
    let label: String
    @Binding var text: String
    var prompt = ""
    var secure = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Group {
                if secure {
                    SecureField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textTertiary))
                } else {
                    TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textTertiary))
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Theme.textPrimary)
            .focused($focused)
            .autocorrectionDisabled()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(focused ? Theme.lapis.opacity(0.55) : Theme.stroke, lineWidth: 1)
            )
        }
    }
}

// MARK: - Provider

private struct ProviderSettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    enum TestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    @State private var testState: TestState = .idle
    @State private var showKey = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsCard(
                    title: "OpenAI-compatible endpoint",
                    footer: "The API key is stored in the macOS Keychain. Local servers (Ollama, LM Studio, vLLM) don't need a key."
                ) {
                    HStack {
                        Text("Provider")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Picker("", selection: $settings.provider) {
                            ForEach(ProviderPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: settings.provider) { _, _ in
                            settings.applyPresetDefaults()
                            testState = .idle
                        }
                    }

                    ThemedField(label: "Base URL", text: $settings.baseURL, prompt: "https://api.openai.com/v1")

                    HStack(alignment: .bottom, spacing: 8) {
                        ThemedField(
                            label: "API Key",
                            text: $settings.apiKey,
                            prompt: settings.provider.needsAPIKey ? "sk-…" : "not required for local servers",
                            secure: !showKey
                        )
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.field))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help(showKey ? "Hide key" : "Show key")
                    }

                    ThemedField(label: "Model", text: $settings.model, prompt: "e.g. gpt-4.1-mini, qwen3:8b")
                }

                SettingsCard(
                    title: "Reasoning",
                    footer: "Sends the right knob per provider — OpenAI: reasoning_effort · OpenRouter: reasoning.enabled=false · Ollama: think=false · vLLM: chat_template_kwargs. Inline <think> blocks are always stripped as a fallback."
                ) {
                    Toggle("Disable model thinking / reasoning", isOn: $settings.disableThinking)
                        .toggleStyle(PillToggleStyle(tint: Theme.gold))
                }

                SettingsCard(title: "Connection") {
                    HStack(spacing: 10) {
                        Button {
                            runTest()
                        } label: {
                            if testState == .testing {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Testing…")
                                }
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(testState == .testing)

                        switch testState {
                        case .success(let result):
                            Label("\"Hello\" → \(result)", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.green)
                                .lineLimit(1)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.coral)
                                .lineLimit(2)
                                .help(message)
                        default:
                            EmptyView()
                        }
                        Spacer()
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    private func runTest() {
        testState = .testing
        let config = TranslationService.currentConfig()
        Task {
            do {
                let result = try await TranslationService.shared.translateOnce(
                    text: "Hello",
                    direction: .enToAr,
                    config: config
                )
                testState = .success(String(result.prefix(40)))
            } catch {
                let message = (error as? TranslationError)?.errorDescription
                    ?? error.localizedDescription
                testState = .failure(String(message.prefix(120)))
            }
        }
    }
}

// MARK: - Behavior

private struct BehaviorSettingsTab: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var history: HistoryStore
    @State private var accessibilityGranted = Permissions.accessibilityGranted

    private let permissionTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsCard(title: "Translation") {
                    Toggle("Auto-translate while typing", isOn: $settings.autoTranslate)
                        .toggleStyle(PillToggleStyle())
                    Toggle("Watch clipboard and translate copied text", isOn: $settings.clipboardWatcher)
                        .toggleStyle(PillToggleStyle(tint: Theme.gold))
                }

                SettingsCard(
                    title: "Hotkey",
                    footer: "Hold ⌘ and tap C twice quickly on selected text in any app — a floating translation appears near the cursor. With “Replace in place” on, the translation is pasted over the original selection."
                ) {
                    Toggle("Double ⌘C hotkey", isOn: $settings.hotkeyEnabled)
                        .toggleStyle(PillToggleStyle())
                    Toggle("Replace in place", isOn: $settings.replaceInPlace)
                        .toggleStyle(PillToggleStyle(tint: Theme.gold))
                }

                SettingsCard(title: "Permissions") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accessibilityGranted ? Theme.green : Theme.gold)
                            .frame(width: 7, height: 7)
                            .shadow(color: (accessibilityGranted ? Theme.green : Theme.gold).opacity(0.6), radius: 3)
                        Text(accessibilityGranted
                             ? "Accessibility access granted"
                             : "Accessibility access required for the hotkey and replace-in-place")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if !accessibilityGranted {
                            Button("Grant…") {
                                Permissions.requestAccessibility()
                                Permissions.openAccessibilitySettings()
                            }
                            .buttonStyle(GhostButtonStyle(tint: Theme.gold))
                        }
                    }
                }

                SettingsCard(
                    title: "History",
                    footer: "History is saved to ~/Library/Application Support/TLang/history.json and never leaves this Mac."
                ) {
                    Toggle("Save translation history", isOn: $settings.saveHistory)
                        .toggleStyle(PillToggleStyle())
                    HStack {
                        Text("\(history.entries.count) entries stored locally")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Button("Clear History…") {
                            history.clearAll(keepPinned: false)
                        }
                        .buttonStyle(GhostButtonStyle(tint: Theme.coral))
                        .disabled(history.entries.isEmpty)
                    }
                }

                SettingsCard(title: "App") {
                    HStack {
                        Text("Appearance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(AppearanceMode.allCases) { mode in
                                let selected = settings.appearance == mode
                                Button {
                                    settings.appearance = mode
                                } label: {
                                    Label(mode.label, systemImage: mode.icon)
                                        .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                                        .foregroundStyle(selected ? Theme.textPrimary : Theme.textTertiary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(selected ? Theme.cardHover : .clear))
                                        .overlay(
                                            Capsule().strokeBorder(selected ? Theme.strokeStrong : .clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(Capsule().fill(Theme.field))
                        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .toggleStyle(PillToggleStyle())
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.coral)
                    }
                    Toggle("Hide Dock icon (menu bar only)", isOn: $settings.hideDockIcon)
                        .toggleStyle(PillToggleStyle())
                }
            }
        }
        .scrollIndicators(.never)
        .onReceive(permissionTimer) { _ in
            accessibilityGranted = Permissions.accessibilityGranted
        }
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            LogoMark(size: 64)
            Text("TLang")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Arabic ⇄ English translation, powered by any\nOpenAI-compatible chat-completions API.")
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Text("Version 1.2.0")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.field))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))

            VStack(alignment: .leading, spacing: 7) {
                Label("Copy text anywhere — TLang translates it automatically", systemImage: "doc.on.clipboard")
                Label("Hold ⌘ and double-tap C for the floating translator", systemImage: "keyboard")
                Label("History is stored locally on this Mac", systemImage: "internaldrive")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 4)

            Rectangle()
                .fill(Theme.borderGradient)
                .frame(width: 180, height: 1)
                .padding(.vertical, 4)

            VStack(spacing: 6) {
                Text("Made with Claude by Raad Kasem")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 16) {
                    Link("github.com/raadkasem",
                         destination: URL(string: "https://github.com/raadkasem")!)
                    Link("T-Lang on GitHub",
                         destination: URL(string: "https://github.com/raadkasem/T-Lang")!)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.gold)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

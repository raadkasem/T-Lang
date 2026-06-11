import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ProviderSettingsTab()
                .tabItem { Label("Provider", systemImage: "server.rack") }
            BehaviorSettingsTab()
                .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 520)
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
        Form {
            Section {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: settings.provider) { _, _ in
                    settings.applyPresetDefaults()
                    testState = .idle
                }

                TextField("Base URL", text: $settings.baseURL, prompt: Text("https://api.openai.com/v1"))
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()

                HStack {
                    if showKey {
                        TextField("API Key", text: $settings.apiKey, prompt: Text(keyPrompt))
                            .font(.system(size: 12, design: .monospaced))
                            .autocorrectionDisabled()
                    } else {
                        SecureField("API Key", text: $settings.apiKey, prompt: Text(keyPrompt))
                    }
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                TextField("Model", text: $settings.model, prompt: Text("e.g. gpt-4.1-mini, qwen3:8b"))
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()
            } header: {
                Text("OpenAI-compatible endpoint")
            } footer: {
                Text("The API key is stored in the macOS Keychain. Local servers (Ollama, LM Studio, vLLM) don't need a key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Disable model thinking / reasoning", isOn: $settings.disableThinking)
            } footer: {
                Text("Sends the right knob per provider — OpenAI: reasoning_effort · OpenRouter: reasoning.enabled=false · Ollama: think=false · vLLM: chat_template_kwargs.enable_thinking=false. Inline <think> blocks are always stripped from the output as a fallback (covers LM Studio and custom servers).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
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
                    .disabled(testState == .testing)

                    switch testState {
                    case .success(let result):
                        Label("\"Hello\" → \(result)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .help(message)
                    default:
                        EmptyView()
                    }
                }
                .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }

    private var keyPrompt: String {
        settings.provider.needsAPIKey ? "sk-…" : "not required for local servers"
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
        Form {
            Section("Translation") {
                Toggle("Auto-translate while typing", isOn: $settings.autoTranslate)
                Toggle("Watch clipboard and translate copied text", isOn: $settings.clipboardWatcher)
            }

            Section {
                Toggle("Double ⌘C hotkey", isOn: $settings.hotkeyEnabled)
                Toggle("Replace in place", isOn: $settings.replaceInPlace)
            } header: {
                Text("Hotkey")
            } footer: {
                Text("Hold ⌘ and tap C twice quickly on selected text in any app — a floating translation appears near the cursor. With “Replace in place” on, the translation is automatically pasted over the original selection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Circle()
                        .fill(accessibilityGranted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(accessibilityGranted
                         ? "Accessibility access granted"
                         : "Accessibility access required for the hotkey and replace-in-place")
                        .font(.system(size: 12))
                    Spacer()
                    if !accessibilityGranted {
                        Button("Grant…") {
                            Permissions.requestAccessibility()
                            Permissions.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Permissions")
            }

            Section {
                Toggle("Save translation history", isOn: $settings.saveHistory)
                HStack {
                    Text("\(history.entries.count) entries stored locally")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear History…") {
                        history.clearAll(keepPinned: false)
                    }
                    .controlSize(.small)
                    .disabled(history.entries.isEmpty)
                }
            } header: {
                Text("History")
            } footer: {
                Text("History is saved to ~/Library/Application Support/TLang/history.json and never leaves this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("App") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Hide Dock icon (menu bar only)", isOn: $settings.hideDockIcon)
            }
        }
        .formStyle(.grouped)
        .onReceive(permissionTimer) { _ in
            accessibilityGranted = Permissions.accessibilityGranted
        }
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: TLangApp.menuBarSymbol)
                .font(.system(size: 42))
                .foregroundStyle(.tint)
            Text("TLang")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("Arabic ⇄ English translation, powered by any\nOpenAI-compatible chat-completions API.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Divider().frame(width: 200)
            VStack(alignment: .leading, spacing: 6) {
                Label("Copy text anywhere — TLang translates it automatically", systemImage: "doc.on.clipboard")
                Label("Hold ⌘ and double-tap C for the floating translator", systemImage: "keyboard")
                Label("History is stored locally on this Mac", systemImage: "internaldrive")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            Divider().frame(width: 200)
            VStack(spacing: 5) {
                Text("Made with Claude by Raad Kasem")
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 14) {
                    Link("github.com/raadkasem",
                         destination: URL(string: "https://github.com/raadkasem")!)
                    Link("T-Lang on GitHub",
                         destination: URL(string: "https://github.com/raadkasem/T-Lang")!)
                }
                .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

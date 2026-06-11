import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum K {
        static let provider = "provider"
        static let baseURL = "baseURL"
        static let model = "model"
        static let autoTranslate = "autoTranslate"
        static let clipboardWatcher = "clipboardWatcher"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let replaceInPlace = "replaceInPlace"
        static let disableThinking = "disableThinking"
        static let saveHistory = "saveHistory"
        static let hideDockIcon = "hideDockIcon"
        static let launchAtLogin = "launchAtLogin"
        static let appearance = "appearanceMode"
    }

    private let defaults = UserDefaults.standard

    @Published var provider: ProviderPreset {
        didSet { defaults.set(provider.rawValue, forKey: K.provider) }
    }
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: K.baseURL) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: K.model) }
    }
    @Published var apiKey: String {
        didSet { scheduleKeychainSave() }
    }
    private var keychainSaveTask: Task<Void, Never>?
    @Published var autoTranslate: Bool {
        didSet { defaults.set(autoTranslate, forKey: K.autoTranslate) }
    }
    @Published var clipboardWatcher: Bool {
        didSet { defaults.set(clipboardWatcher, forKey: K.clipboardWatcher) }
    }
    @Published var hotkeyEnabled: Bool {
        didSet { defaults.set(hotkeyEnabled, forKey: K.hotkeyEnabled) }
    }
    @Published var replaceInPlace: Bool {
        didSet { defaults.set(replaceInPlace, forKey: K.replaceInPlace) }
    }
    @Published var disableThinking: Bool {
        didSet { defaults.set(disableThinking, forKey: K.disableThinking) }
    }
    @Published var saveHistory: Bool {
        didSet { defaults.set(saveHistory, forKey: K.saveHistory) }
    }
    @Published var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: K.hideDockIcon) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: K.launchAtLogin)
            applyLaunchAtLogin()
        }
    }
    @Published var launchAtLoginError: String?
    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: K.appearance) }
    }

    private init() {
        let d = UserDefaults.standard
        provider = ProviderPreset(rawValue: d.string(forKey: K.provider) ?? "") ?? .openai
        baseURL = d.string(forKey: K.baseURL) ?? ProviderPreset.openai.defaultBaseURL
        model = d.string(forKey: K.model) ?? ProviderPreset.openai.defaultModel
        apiKey = KeychainStore.get("api-key") ?? ""
        autoTranslate = Self.bool(d, K.autoTranslate, default: true)
        clipboardWatcher = Self.bool(d, K.clipboardWatcher, default: true)
        hotkeyEnabled = Self.bool(d, K.hotkeyEnabled, default: true)
        replaceInPlace = Self.bool(d, K.replaceInPlace, default: false)
        disableThinking = Self.bool(d, K.disableThinking, default: true)
        saveHistory = Self.bool(d, K.saveHistory, default: true)
        hideDockIcon = Self.bool(d, K.hideDockIcon, default: false)
        launchAtLogin = Self.bool(d, K.launchAtLogin, default: false)
        appearance = AppearanceMode(rawValue: d.string(forKey: K.appearance) ?? "") ?? .system
    }

    private static func bool(_ d: UserDefaults, _ key: String, default def: Bool) -> Bool {
        d.object(forKey: key) == nil ? def : d.bool(forKey: key)
    }

    /// Switch base URL / model to the preset defaults when the user picks a preset.
    func applyPresetDefaults() {
        guard provider != .custom else { return }
        baseURL = provider.defaultBaseURL
        if !provider.defaultModel.isEmpty {
            model = provider.defaultModel
        }
    }

    /// Keychain writes are synchronous IPC — doing one per keystroke freezes
    /// the API-key field. Debounce and write off the main thread instead.
    private func scheduleKeychainSave() {
        keychainSaveTask?.cancel()
        let value = apiKey
        keychainSaveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            KeychainStore.set(value, account: "api-key")
        }
    }

    /// Synchronously persist anything still pending (called on app quit).
    func flushPendingWrites() {
        keychainSaveTask?.cancel()
        keychainSaveTask = nil
        KeychainStore.set(apiKey, account: "api-key")
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }
}

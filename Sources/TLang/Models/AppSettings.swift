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
        didSet {
            guard provider != oldValue else { return }
            defaults.set(provider.rawValue, forKey: K.provider)
            flushPendingKeychain(for: oldValue)
            loadProfile()
        }
    }
    @Published var baseURL: String {
        didSet {
            guard !isLoadingProfile else { return }
            defaults.set(baseURL, forKey: Self.profileKey("baseURL", provider))
        }
    }
    @Published var model: String {
        didSet {
            guard !isLoadingProfile else { return }
            defaults.set(model, forKey: Self.profileKey("model", provider))
        }
    }
    @Published var apiKey: String {
        didSet {
            guard !isLoadingProfile else { return }
            scheduleKeychainSave()
        }
    }
    private var keychainSaveTask: Task<Void, Never>?
    private var isLoadingProfile = false
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
        let p = ProviderPreset(rawValue: d.string(forKey: K.provider) ?? "") ?? .openai

        // Migrate legacy single-profile storage (pre-1.3) into the current
        // provider's profile, so nothing the user configured is lost.
        if let legacyURL = d.string(forKey: K.baseURL) {
            if d.string(forKey: Self.profileKey("baseURL", p)) == nil {
                d.set(legacyURL, forKey: Self.profileKey("baseURL", p))
            }
            d.removeObject(forKey: K.baseURL)
        }
        if let legacyModel = d.string(forKey: K.model) {
            if d.string(forKey: Self.profileKey("model", p)) == nil {
                d.set(legacyModel, forKey: Self.profileKey("model", p))
            }
            d.removeObject(forKey: K.model)
        }
        if let legacyKey = KeychainStore.get("api-key") {
            if KeychainStore.get(Self.keychainAccount(p)) == nil {
                KeychainStore.set(legacyKey, account: Self.keychainAccount(p))
            }
            KeychainStore.delete("api-key")
        }

        provider = p
        baseURL = d.string(forKey: Self.profileKey("baseURL", p)) ?? p.defaultBaseURL
        model = d.string(forKey: Self.profileKey("model", p)) ?? p.defaultModel
        apiKey = KeychainStore.get(Self.keychainAccount(p)) ?? ""
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

    // MARK: Per-provider profiles

    /// Each provider keeps its own base URL / model (UserDefaults) and API key
    /// (Keychain), so switching presets never loses configuration.
    private static func profileKey(_ field: String, _ p: ProviderPreset) -> String {
        "\(field).\(p.rawValue)"
    }

    private static func keychainAccount(_ p: ProviderPreset) -> String {
        "api-key.\(p.rawValue)"
    }

    /// Load the newly selected provider's saved profile (or its defaults).
    private func loadProfile() {
        isLoadingProfile = true
        baseURL = defaults.string(forKey: Self.profileKey("baseURL", provider)) ?? provider.defaultBaseURL
        model = defaults.string(forKey: Self.profileKey("model", provider)) ?? provider.defaultModel
        apiKey = KeychainStore.get(Self.keychainAccount(provider)) ?? ""
        isLoadingProfile = false
    }

    /// Screenshot mode only: display representative demo values in the
    /// provider fields without persisting them anywhere.
    func showDemoProfileForScreenshots() {
        isLoadingProfile = true
        baseURL = "https://api.openai.com/v1"
        model = "gpt-4.1-mini"
        apiKey = "sk-demo-key-not-real"
        isLoadingProfile = false
    }

    /// Keychain writes are synchronous IPC — doing one per keystroke freezes
    /// the API-key field. Debounce and write off the main thread instead.
    private func scheduleKeychainSave() {
        keychainSaveTask?.cancel()
        let value = apiKey
        let account = Self.keychainAccount(provider)
        keychainSaveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            KeychainStore.set(value, account: account)
        }
    }

    /// If a debounced key write is still pending when the provider changes,
    /// persist it under the OLD provider's account before loading the new one.
    private func flushPendingKeychain(for old: ProviderPreset) {
        guard keychainSaveTask != nil else { return }
        keychainSaveTask?.cancel()
        keychainSaveTask = nil
        KeychainStore.set(apiKey, account: Self.keychainAccount(old))
    }

    /// Synchronously persist anything still pending (called on app quit).
    func flushPendingWrites() {
        keychainSaveTask?.cancel()
        keychainSaveTask = nil
        KeychainStore.set(apiKey, account: Self.keychainAccount(provider))
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

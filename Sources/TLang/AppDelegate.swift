import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var appMainMenu: NSMenu?
    private var editShortcutMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        installMainMenu()
        installEditShortcutFallback()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reassertMainMenu),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        applyActivationPolicy()
        wireServices()
        openMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        HistoryStore.shared.saveNow()
        AppSettings.shared.flushPendingWrites()
    }

    // MARK: - Services

    private func wireServices() {
        let settings = AppSettings.shared

        ClipboardWatcher.shared.onText = { text in
            let vm = TranslatorViewModel.main
            guard text != vm.sourceText else { return }
            vm.setTexts(source: text, output: "")
            vm.translateNow()
        }
        HotkeyManager.shared.onDoubleCopy = {
            FloatingPanelController.shared.handleDoubleCopy()
        }

        if settings.clipboardWatcher {
            ClipboardWatcher.shared.start()
        }
        if settings.hotkeyEnabled {
            HotkeyManager.shared.start()
        }

        settings.$clipboardWatcher
            .dropFirst()
            .sink { on in
                Task { @MainActor in
                    on ? ClipboardWatcher.shared.start() : ClipboardWatcher.shared.stop()
                }
            }
            .store(in: &cancellables)

        settings.$hotkeyEnabled
            .dropFirst()
            .sink { on in
                Task { @MainActor in
                    if on {
                        Permissions.requestAccessibility()
                        HotkeyManager.shared.start()
                    } else {
                        HotkeyManager.shared.stop()
                    }
                }
            }
            .store(in: &cancellables)

        settings.$replaceInPlace
            .dropFirst()
            .sink { on in
                Task { @MainActor in
                    if on { Permissions.requestAccessibility() }
                }
            }
            .store(in: &cancellables)

        settings.$hideDockIcon
            .dropFirst()
            .sink { _ in
                Task { @MainActor in
                    AppDelegate.shared?.applyActivationPolicy()
                }
            }
            .store(in: &cancellables)
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(AppSettings.shared.hideDockIcon ? .accessory : .regular)
    }

    // MARK: - Windows

    func openMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 940, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "TLang"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 720, height: 440)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("TLangMainWindow")
            window.contentView = NSHostingView(
                rootView: MainView()
                    .environmentObject(AppSettings.shared)
                    .environmentObject(HistoryStore.shared)
            )
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    func openSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "TLang Settings"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(AppSettings.shared)
                    .environmentObject(HistoryStore.shared)
            )
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings(_ sender: Any?) {
        openSettingsWindow()
    }

    @objc private func showMainWindow(_ sender: Any?) {
        openMainWindow()
    }

    // MARK: - Main menu

    /// MenuBarExtra-only SwiftUI apps don't always get a full main menu;
    /// without an Edit menu, ⌘C/⌘V/⌘A stop working inside text views.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About TLang",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let translatorItem = NSMenuItem(
            title: "Open Translator",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: "n"
        )
        translatorItem.target = self
        appMenu.addItem(translatorItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide TLang",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(
            withTitle: "Quit TLang",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        appMainMenu = mainMenu
        NSApp.mainMenu = mainMenu
    }

    /// SwiftUI owns NSApp.mainMenu in MenuBarExtra apps and may swap our menu
    /// out after launch — put it back whenever one of our windows becomes key.
    @objc private func reassertMainMenu() {
        if let menu = appMainMenu, NSApp.mainMenu !== menu {
            NSApp.mainMenu = menu
        }
    }

    /// Belt-and-braces: handle the standard edit shortcuts at the event level
    /// and send them straight down the responder chain, so ⌘V/⌘C/⌘X/⌘A/⌘Z
    /// work in every window even if the Edit menu is missing or disabled.
    private func installEditShortcutFallback() {
        editShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection([.command, .option, .control]) == .command,
                  let key = event.shortcutKey
            else { return event }

            let hasShift = event.modifierFlags.contains(.shift)
            let action: Selector?
            switch (key, hasShift) {
            case ("v", false): action = #selector(NSText.paste(_:))
            case ("c", false): action = #selector(NSText.copy(_:))
            case ("x", false): action = #selector(NSText.cut(_:))
            case ("a", false): action = #selector(NSText.selectAll(_:))
            case ("z", false): action = Selector(("undo:"))
            case ("z", true): action = Selector(("redo:"))
            default: action = nil
            }

            guard let action, NSApp.sendAction(action, to: nil, from: nil) else {
                return event
            }
            return nil
        }
    }
}

import AppKit
import SwiftUI

@main
struct TLangApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static let menuBarSymbol: String =
        NSImage(systemSymbolName: "translate", accessibilityDescription: nil) != nil
            ? "translate"
            : "character.bubble"

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(AppSettings.shared)
        } label: {
            Image(systemName: Self.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}

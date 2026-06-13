import Combine
import Sparkle
import SwiftUI

/// Wraps Sparkle's updater so SwiftUI views can drive "Check for Updates" and
/// the automatic-checks toggle. The appcast and EdDSA public key are configured
/// in Info.plist (SUFeedURL / SUPublicEDKey).
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    let controller: SPUStandardUpdaterController

    /// True once Sparkle is ready to check (disabled briefly at launch).
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecks: Bool

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecks = enabled
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

/// Reusable "Check for Updates" button for SwiftUI surfaces.
struct CheckForUpdatesButton: View {
    @ObservedObject var updater = UpdaterController.shared
    var label: String = "Check for Updates…"

    var body: some View {
        Button(label) {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}

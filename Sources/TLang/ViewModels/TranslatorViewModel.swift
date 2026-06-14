import Foundation
import SwiftUI

@MainActor
final class TranslatorViewModel: ObservableObject {
    /// Shared by the main window, menu bar popover, and clipboard watcher.
    static let main = TranslatorViewModel()
    /// Dedicated instance for the floating hotkey panel.
    static let panel = TranslatorViewModel()

    @Published var sourceText = "" {
        didSet { handleSourceChange(oldValue: oldValue) }
    }
    @Published var outputText = ""
    @Published var isTranslating = false
    @Published var isThinkingPhase = false
    @Published var retryAttempt = 0
    @Published var errorMessage: String?
    @Published var direction: Direction = .enToAr

    /// Alternative phrasings (index 0 is always the primary `outputText`).
    @Published var alternatives: [String] = []
    @Published var variantIndex = 0
    @Published var loadingAlternatives = false

    var totalVariants: Int { 1 + alternatives.count }

    /// The variant currently shown in the output pane.
    var displayedText: String {
        guard variantIndex > 0, variantIndex - 1 < alternatives.count else { return outputText }
        return alternatives[variantIndex - 1]
    }

    /// Alternatives are offered for short, finished translations only.
    var canLoadAlternatives: Bool {
        guard !isTranslating, errorMessage == nil, !outputText.isEmpty else { return false }
        let words = sourceText.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
        return words <= 12
    }

    private var translateTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var generation = 0
    private var suppressAuto = false

    private init() {}

    private func handleSourceChange(oldValue: String) {
        guard sourceText != oldValue else { return }
        if !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            direction = LanguageDetector.detect(sourceText)
        }
        errorMessage = nil
        debounceTask?.cancel()
        guard !suppressAuto, AppSettings.shared.autoTranslate else { return }
        let snapshot = sourceText
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, let self, self.sourceText == snapshot else { return }
            self.translateNow()
        }
    }

    /// Sets text without triggering auto-translate (history loads, swaps).
    func setTexts(source: String, output: String, direction: Direction? = nil) {
        suppressAuto = true
        sourceText = source
        outputText = output
        suppressAuto = false
        alternatives = []
        variantIndex = 0
        loadingAlternatives = false
        if let direction {
            self.direction = direction
        }
    }

    func translateNow(onComplete: ((String) -> Void)? = nil) {
        debounceTask?.cancel()
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        translateTask?.cancel()
        generation += 1
        let gen = generation
        SpeechService.shared.stop()

        let dir = LanguageDetector.detect(text)
        direction = dir
        isTranslating = true
        isThinkingPhase = false
        retryAttempt = 0
        errorMessage = nil
        outputText = ""
        alternatives = []
        variantIndex = 0
        loadingAlternatives = false
        let config = TranslationService.currentConfig()

        let onRetry: @Sendable (Int) -> Void = { [weak self] attempt in
            Task { @MainActor in
                guard let self, self.generation == gen else { return }
                self.retryAttempt = attempt
            }
        }

        translateTask = Task { [weak self] in
            var raw = ""
            var lastUIUpdate = ContinuousClock.now
            do {
                for try await piece in TranslationService.shared.stream(text: text, direction: dir, config: config, onRetry: onRetry) {
                    guard let self, self.generation == gen else { return }
                    if self.retryAttempt != 0 { self.retryAttempt = 0 }
                    raw += piece
                    // Throttle @Published writes — re-rendering on every token
                    // makes the whole app stutter during streaming.
                    let now = ContinuousClock.now
                    if now - lastUIUpdate >= .milliseconds(80) {
                        lastUIUpdate = now
                        self.applyStreamSnapshot(raw)
                    }
                }
                guard let self, self.generation == gen else { return }
                let final = ThinkFilter.filter(raw).visible
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.outputText = final
                self.isTranslating = false
                self.isThinkingPhase = false
                self.retryAttempt = 0
                if !final.isEmpty {
                    HistoryStore.shared.add(source: text, translation: final, direction: dir)
                }
                onComplete?(final)
            } catch is CancellationError {
                // superseded by a newer request
            } catch {
                guard let self, self.generation == gen else { return }
                self.errorMessage = Self.friendlyMessage(for: error)
                self.isTranslating = false
                self.isThinkingPhase = false
                self.retryAttempt = 0
            }
        }
    }

    func stop() {
        generation += 1
        translateTask?.cancel()
        debounceTask?.cancel()
        isTranslating = false
        isThinkingPhase = false
        retryAttempt = 0
    }

    /// Fetches alternative phrasings for the current short translation.
    func loadAlternatives() {
        guard canLoadAlternatives, alternatives.isEmpty, !loadingAlternatives else { return }
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let dir = direction
        let primary = outputText
        let config = TranslationService.currentConfig()
        loadingAlternatives = true
        let gen = generation
        Task { [weak self] in
            do {
                let alts = try await TranslationService.shared.alternatives(
                    text: text, direction: dir, config: config, count: 2, excluding: primary)
                guard let self, self.generation == gen else { return }
                self.alternatives = alts
                self.loadingAlternatives = false
                if !alts.isEmpty { self.variantIndex = 1 }
            } catch {
                guard let self, self.generation == gen else { return }
                self.loadingAlternatives = false
            }
        }
    }

    func showVariant(_ index: Int) {
        guard index >= 0, index < totalVariants else { return }
        variantIndex = index
    }

    /// Starts/stops microphone dictation into the source pane, using the
    /// source language of the current direction.
    func toggleDictation() {
        let identifier = direction.sourceIsRTL ? "ar-SA" : "en-US"
        DictationService.shared.toggle(
            locale: Locale(identifier: identifier),
            onPartial: { [weak self] text in self?.setDictatedSource(text) },
            onFinish: { [weak self] finalText in
                guard let self else { return }
                // Keep the recognized text in the source pane, then translate it.
                self.setDictatedSource(finalText)
                if AppSettings.shared.autoTranslate,
                   !self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.translateNow()
                }
            }
        )
    }

    private func setDictatedSource(_ text: String) {
        guard !text.isEmpty else { return }
        suppressAuto = true
        sourceText = text
        suppressAuto = false
    }

    func swap() {
        let output = outputText
        guard !output.isEmpty else { return }
        setTexts(source: output, output: "", direction: direction.flipped)
        if AppSettings.shared.autoTranslate {
            translateNow()
        }
    }

    func clear() {
        stop()
        SpeechService.shared.stop()
        setTexts(source: "", output: "")
        errorMessage = nil
    }

    /// Applies a mid-stream snapshot, skipping the tag filter when no tags can exist.
    private func applyStreamSnapshot(_ raw: String) {
        let visible: String
        let thinking: Bool
        if raw.contains("<") {
            let filtered = ThinkFilter.filter(raw)
            visible = filtered.visible
            thinking = filtered.thinking && filtered.visible.isEmpty
        } else {
            visible = raw
            thinking = false
        }
        if isThinkingPhase != thinking {
            isThinkingPhase = thinking
        }
        outputText = Self.trimLeading(visible)
    }

    private static func trimLeading(_ s: String) -> String {
        guard let first = s.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) else { return "" }
        return String(s[first...])
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let e = error as? TranslationError {
            return e.errorDescription ?? "Translation failed."
        }
        if let e = error as? URLError {
            switch e.code {
            case .cannotConnectToHost, .cannotFindHost:
                return "Could not reach the server — is it running? Check the base URL in Settings."
            case .notConnectedToInternet, .networkConnectionLost:
                return "No network connection."
            case .timedOut:
                return "The request timed out."
            case .secureConnectionFailed, .serverCertificateUntrusted:
                return "Secure connection failed — check the base URL scheme."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

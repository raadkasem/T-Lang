import AVFoundation
import Foundation

/// Text-to-speech via the system synthesizer. Free, offline, and picks the
/// best installed voice per language (users can add Enhanced/Premium voices
/// in System Settings → Accessibility → Spoken Content).
@MainActor
final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    /// Identifier of the pane currently speaking ("source", "output", "panel").
    @Published private(set) var speakingID: String?

    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(text: String, isArabic: Bool, id: String) {
        if speakingID == id {
            stop()
        } else {
            speak(text: text, isArabic: isArabic, id: id)
        }
    }

    func speak(text: String, isArabic: Bool, id: String) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.bestVoice(isArabic: isArabic)
        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speakingID = nil
    }

    /// Highest-quality installed voice for the language, preferring the
    /// canonical region (ar-001 Majed / en-US) among equal-quality voices.
    static func bestVoice(isArabic: Bool) -> AVSpeechSynthesisVoice? {
        let prefix = isArabic ? "ar" : "en"
        let preferredRegion = isArabic ? "ar-001" : "en-US"

        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .sorted {
                if $0.quality != $1.quality {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return ($0.language == preferredRegion) && ($1.language != preferredRegion)
            }

        return candidates.first
            ?? AVSpeechSynthesisVoice(language: preferredRegion)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingID = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.speakingID = nil
        }
    }
}

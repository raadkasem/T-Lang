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

    /// Best installed voice for the language. English prefers a female voice;
    /// within that, higher quality wins, then the canonical region
    /// (en-US / ar-001 Majed).
    static func bestVoice(isArabic: Bool) -> AVSpeechSynthesisVoice? {
        let prefix = isArabic ? "ar" : "en"
        let preferredRegion = isArabic ? "ar-001" : "en-US"

        // Many compact voices report .unspecified gender — recognize the
        // common female system voices by name as a fallback.
        let knownFemaleNames: Set<String> = [
            "Samantha", "Ava", "Allison", "Susan", "Zoe", "Karen",
            "Moira", "Tessa", "Kate", "Serena", "Fiona", "Nicky",
        ]
        func isFemale(_ voice: AVSpeechSynthesisVoice) -> Bool {
            voice.gender == .female
                || knownFemaleNames.contains(where: { voice.name.hasPrefix($0) })
        }

        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .sorted { a, b in
                if !isArabic, isFemale(a) != isFemale(b) {
                    return isFemale(a)
                }
                if a.quality != b.quality {
                    return a.quality.rawValue > b.quality.rawValue
                }
                return (a.language == preferredRegion) && (b.language != preferredRegion)
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

import AVFoundation
import Speech
import SwiftUI

/// Microphone dictation via on-device speech recognition. Transcribes into the
/// source pane in the language matching the current translation direction.
@MainActor
final class DictationService: NSObject, ObservableObject {
    static let shared = DictationService()

    @Published private(set) var isListening = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var onPartial: ((String) -> Void)?
    private var onFinish: ((String) -> Void)?
    private var lastTranscript = ""

    override private init() { super.init() }

    func toggle(locale: Locale, onPartial: @escaping (String) -> Void, onFinish: @escaping (String) -> Void) {
        if isListening {
            stop()
        } else {
            start(locale: locale, onPartial: onPartial, onFinish: onFinish)
        }
    }

    func start(locale: Locale, onPartial: @escaping (String) -> Void, onFinish: @escaping (String) -> Void) {
        errorMessage = nil
        lastTranscript = ""
        self.onPartial = onPartial
        self.onFinish = onFinish

        requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.errorMessage = "Microphone or speech-recognition access denied. Enable it in System Settings → Privacy."
                return
            }
            do {
                try self.beginRecording(locale: locale)
            } catch {
                self.errorMessage = "Couldn't start dictation: \(error.localizedDescription)"
                self.cleanup()
            }
        }
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        isListening = false
        onFinish?(lastTranscript)
    }

    private func beginRecording(locale: Locale) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available for \(locale.identifier)."
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    // Ignore empty transcripts so a late/flush result can't wipe
                    // the text the user just dictated.
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty {
                        self.lastTranscript = text
                        self.onPartial?(text)
                    }
                    if result.isFinal { self.stop() }
                }
                if error != nil {
                    self.stop()
                }
            }
        }
    }

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request = nil
        task = nil
        isListening = false
    }

    private func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            let speechOK = speechStatus == .authorized
            AVCaptureDevice.requestAccess(for: .audio) { micOK in
                Task { @MainActor in completion(speechOK && micOK) }
            }
        }
    }
}

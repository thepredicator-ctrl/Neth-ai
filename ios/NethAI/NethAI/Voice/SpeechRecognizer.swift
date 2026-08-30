import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - SpeechRecognizer
// Wraps SFSpeechRecognizer for on-device speech recognition.
// Falls back to on-device when available; never requires cloud.

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var error: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer: SFSpeechRecognizer?
    private var levelTimer: Timer?
    private var silenceTimer: Timer?

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        let micGranted: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return status == .authorized && micGranted
    }

    func startListening() async {
        guard await requestAuthorization() else {
            self.error = "Microphone or speech recognition permission denied."
            return
        }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            self.error = "Speech recognizer not available."
            return
        }

        await MainActor.run {
            self.transcript = ""
            self.error = nil
            self.isListening = true
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = true
        }
        self.recognitionRequest = request

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Audio session error: \(String(describing: error))"
            self.isListening = false
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            // measure RMS for orb reactivity
            let frameLen = Int(buffer.frameLength)
            guard frameLen > 0 else { return }
            if let channelData = buffer.floatChannelData?[0] {
                var sum: Float = 0
                for i in 0..<frameLen {
                    let v = channelData[i]
                    sum += v * v
                }
                let rms = sqrt(sum / Float(frameLen))
                DispatchQueue.main.async {
                    self.audioLevel = min(1.0, rms * 60)
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.error = "Audio engine start failed: \(String(describing: error))"
            self.isListening = false
            return
        }

        self.recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    self.error = String(describing: error)
                    self.isListening = false
                }
                if result?.isFinal == true {
                    self.isListening = false
                }
            }
        }
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancel() {
        recognitionTask?.cancel()
        stopListening()
        transcript = ""
    }
}

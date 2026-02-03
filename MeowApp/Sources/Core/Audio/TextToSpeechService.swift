import AVFoundation

/// Unified TTS Service - uses ElevenLabs when available, AVSpeechSynthesizer as fallback
@MainActor
@Observable
final class TextToSpeechService: NSObject {
    var isSpeaking = false
    var speakingMessageID: UUID?
    var autoSpeak = false
    var isLoading = false
    var error: String?

    // ElevenLabs service (primary)
    private let elevenLabs = ElevenLabsTTSService()
    // Apple TTS (fallback)
    private let synthesizer = AVSpeechSynthesizer()
    // User preference
    var useElevenLabs = true

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, messageID: UUID? = nil) {
        let apiKey = SharedConfig.elevenLabsAPIKey

        if useElevenLabs && !apiKey.isEmpty {
            // Use ElevenLabs
            Task {
                await elevenLabs.speak(text, messageID: messageID, apiKey: apiKey)
                // Sync state
                self.isSpeaking = elevenLabs.isSpeaking
                self.speakingMessageID = elevenLabs.speakingMessageID
                self.isLoading = elevenLabs.isLoading
                self.error = elevenLabs.error
            }
        } else {
            // Fallback to Apple TTS
            speakWithApple(text, messageID: messageID)
        }
    }

    private func speakWithApple(_ text: String, messageID: UUID? = nil) {
        stopApple()
        let clean = stripMarkdown(text)
        guard !clean.isEmpty else { return }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "it-IT")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0

        speakingMessageID = messageID
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        // Stop both services
        elevenLabs.stop()
        stopApple()
        isSpeaking = false
        isLoading = false
        speakingMessageID = nil
    }

    private func stopApple() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        deactivateAudioSession()
    }

    func toggleSpeak(_ text: String, messageID: UUID) {
        if speakingMessageID == messageID && (isSpeaking || isLoading) {
            stop()
        } else {
            speak(text, messageID: messageID)
        }
    }

    /// Sync state from ElevenLabs service (call periodically if needed)
    func syncElevenLabsState() {
        if useElevenLabs {
            isSpeaking = elevenLabs.isSpeaking
            speakingMessageID = elevenLabs.speakingMessageID
            isLoading = elevenLabs.isLoading
            error = elevenLabs.error
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
        #endif
    }

    // MARK: - Markdown Stripping

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // Code blocks
        result = result.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )
        // Headers
        result = result.replacingOccurrences(
            of: "^#{1,6}\\s*",
            with: "",
            options: .regularExpression
        )
        // Bold/italic
        result = result.replacingOccurrences(
            of: "\\*{1,3}(.*?)\\*{1,3}",
            with: "$1",
            options: .regularExpression
        )
        // Inline code
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "$1",
            options: .regularExpression
        )
        // Links [text](url) -> text
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]+\\)",
            with: "$1",
            options: .regularExpression
        )
        // List markers (per line via NSRegularExpression multiline)
        result = replaceMultiline(in: result, pattern: "^[\\-\\*\\+]\\s+", with: "")
        result = replaceMultiline(in: result, pattern: "^\\d+\\.\\s+", with: "")
        // Horizontal rules
        result = replaceMultiline(in: result, pattern: "^---+$", with: "")
        // Clean up extra whitespace
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replaceMultiline(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
            self.deactivateAudioSession()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }
}

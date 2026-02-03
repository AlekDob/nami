import AVFoundation
import Foundation

/// ElevenLabs TTS Service - streams audio from ElevenLabs API
@MainActor
@Observable
final class ElevenLabsTTSService: NSObject {
    var isSpeaking = false
    var speakingMessageID: UUID?
    var isLoading = false
    var error: String?

    private var audioPlayer: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?

    // ElevenLabs config
    private let defaultVoiceID = "EXAVITQu4vr4xnSDxMaL" // "Sarah" - natural Italian-friendly voice
    private let modelID = "eleven_multilingual_v2" // Best for Italian

    /// Speak text using ElevenLabs TTS
    func speak(_ text: String, messageID: UUID? = nil, apiKey: String) async {
        stop()

        let clean = stripMarkdown(text)
        guard !clean.isEmpty else { return }
        guard !apiKey.isEmpty else {
            error = "ElevenLabs API key not configured"
            return
        }

        isLoading = true
        speakingMessageID = messageID
        error = nil

        currentTask = Task {
            do {
                let audioData = try await fetchAudio(text: clean, apiKey: apiKey)

                guard !Task.isCancelled else { return }

                configureAudioSession()

                audioPlayer = try AVAudioPlayer(data: audioData)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()

                isLoading = false
                isSpeaking = true
                audioPlayer?.play()

            } catch {
                isLoading = false
                isSpeaking = false
                speakingMessageID = nil
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    print("[ElevenLabs] Error: \(error)")
                }
            }
        }

        await currentTask?.value
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        isLoading = false
        speakingMessageID = nil
        deactivateAudioSession()
    }

    // MARK: - API

    private func fetchAudio(text: String, apiKey: String) async throws -> Data {
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(defaultVoiceID)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? [String: Any],
               let message = detail["message"] as? String {
                throw ElevenLabsError.apiError(message)
            }
            throw ElevenLabsError.httpError(httpResponse.statusCode)
        }

        return data
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
        // List markers
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

// MARK: - AVAudioPlayerDelegate

extension ElevenLabsTTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
            self.deactivateAudioSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
            self.error = error?.localizedDescription ?? "Audio decode error"
        }
    }
}

// MARK: - Errors

enum ElevenLabsError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from ElevenLabs"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .apiError(let message):
            return message
        }
    }
}

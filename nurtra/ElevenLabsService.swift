//
//  ElevenLabsService.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/28/25.
//

import Foundation
import AVFoundation

@MainActor
class ElevenLabsService: NSObject {
    private let apiKey: String
    private let voiceID: String
    private let endpoint: String
    private var audioPlayer: AVAudioPlayer?
    private var onAudioFinished: (() -> Void)?
    
    override init() {
        // Read API key and voice ID from Secrets.swift
        let key = Secrets.elevenLabsAPIKey
        let voice = Secrets.elevenLabsVoiceID
        
        if !key.isEmpty && !key.contains("YOUR_ELEVENLABS_API_KEY_HERE") {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("⚠️ Warning: ElevenLabs API key not configured. Please set your key in Secrets.swift")
        }
        
        self.voiceID = voice
        self.endpoint = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)"
        
        super.init()
    }
    
    // MARK: - Text-to-Speech
    
    func playTextToSpeech(text: String, onFinished: (() -> Void)? = nil) async {
        guard !apiKey.isEmpty else {
            print("❌ ElevenLabs API key not configured")
            onFinished?()
            return
        }
        
        guard !text.isEmpty && text != "Loading..." else {
            print("❌ Invalid text for speech synthesis")
            onFinished?()
            return
        }
        
        self.onAudioFinished = onFinished
        
        do {
            print("🎵 Generating speech for: \(text.prefix(50))...")
            
            let audioData = try await generateSpeech(text: text)
            
            print("✅ Speech generated, playing audio...")
            try await playAudio(data: audioData)
            
        } catch let error as ElevenLabsError {
            print("❌ ElevenLabs Error: \(error.localizedDescription)")
            onFinished?()
        } catch {
            print("❌ Unexpected error during speech generation: \(error.localizedDescription)")
            onFinished?()
        }
    }
    
    private func generateSpeech(text: String) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw ElevenLabsError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.1,
                "similarity_boost": 0.8,
                "style": 1,
                "use_speaker_boost": true,
                "speed": 1.1
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ElevenLabsError.encodingFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw ElevenLabsError.unauthorized
        case 429:
            throw ElevenLabsError.rateLimitExceeded
        case 500...599:
            throw ElevenLabsError.serverError
        default:
            throw ElevenLabsError.unknownError(httpResponse.statusCode)
        }
    }
    
    private func playAudio(data: Data) async throws {
        do {
            // Stop any currently playing audio
            audioPlayer?.stop()
            
            // Create and play new audio
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
        } catch {
            throw ElevenLabsError.audioPlaybackFailed
        }
    }
    
    // MARK: - Audio Control
    
    func stopAudio() {
        print("🛑 Stopping audio playback and canceling callbacks")
        audioPlayer?.stop()
        audioPlayer = nil
        // Clear the callback to prevent it from being called
        onAudioFinished = nil
    }
    
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
}

// MARK: - AVAudioPlayerDelegate

extension ElevenLabsService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("🎵 Audio finished playing")
            onAudioFinished?()
            onAudioFinished = nil
        }
    }
}

// MARK: - Error Handling

enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case encodingFailed
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case serverError
    case audioPlaybackFailed
    case unknownError(Int)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ElevenLabs API key not configured"
        case .invalidURL:
            return "Invalid ElevenLabs API URL"
        case .encodingFailed:
            return "Failed to encode request data"
        case .invalidResponse:
            return "Invalid response from ElevenLabs API"
        case .unauthorized:
            return "Unauthorized: Check your ElevenLabs API key"
        case .rateLimitExceeded:
            return "Rate limit exceeded: Too many requests"
        case .serverError:
            return "ElevenLabs server error: Try again later"
        case .audioPlaybackFailed:
            return "Failed to play generated audio"
        case .unknownError(let code):
            return "Unknown error occurred (Status code: \(code))"
        }
    }
}

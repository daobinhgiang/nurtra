//
//  ElevenLabsService.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/28/25.
//

import Foundation
import AVFoundation
import CryptoKit

@MainActor
class ElevenLabsService: NSObject {
    private let apiKey: String
    private let voiceID: String
    private let endpoint: String
    private var audioPlayer: AVAudioPlayer?
    private var onAudioFinished: (() -> Void)?
    
    // Audio cache directory
    private let cacheDirectory: URL
    
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
        
        // Setup cache directory
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("ElevenLabsAudio", isDirectory: true)
        
        super.init()
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            print("📁 Created audio cache directory at: \(cacheDirectory.path)")
        }
    }
    
    // MARK: - Cache Management
    
    /// Generate a unique cache key (filename) for a quote text
    private func cacheKey(for text: String) -> String {
        // Create SHA256 hash of the text to use as filename
        let inputData = Data(text.utf8)
        let hash = SHA256.hash(data: inputData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hashString).mp3"
    }
    
    /// Get the file URL for a cached audio file
    private func cachedAudioURL(for text: String) -> URL {
        let filename = cacheKey(for: text)
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    /// Check if audio is cached for the given text
    private func isCached(text: String) -> Bool {
        let url = cachedAudioURL(for: text)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Save audio data to cache
    private func cacheAudio(data: Data, for text: String) throws {
        let url = cachedAudioURL(for: text)
        try data.write(to: url)
        print("💾 Cached audio to: \(url.lastPathComponent)")
    }
    
    /// Load audio data from cache
    private func loadCachedAudio(for text: String) throws -> Data {
        let url = cachedAudioURL(for: text)
        return try Data(contentsOf: url)
    }
    
    /// Clear all cached audio files
    func clearAudioCache() {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("🗑️ Cleared \(files.count) cached audio files")
        } catch {
            print("❌ Failed to clear audio cache: \(error.localizedDescription)")
        }
    }
    
    /// Pre-cache audio for multiple quotes (used during onboarding)
    func preCacheAudioForQuotes(_ quotes: [String]) async {
        guard !apiKey.isEmpty else {
            print("❌ ElevenLabs API key not configured, skipping pre-cache")
            return
        }
        
        print("🎵 Starting pre-cache for \(quotes.count) quotes...")
        
        var successCount = 0
        var skipCount = 0
        var failCount = 0
        
        for (index, quote) in quotes.enumerated() {
            // Skip if already cached
            if isCached(text: quote) {
                print("⏭️  Quote \(index + 1)/\(quotes.count): Already cached, skipping")
                skipCount += 1
                continue
            }
            
            do {
                print("🎙️  Quote \(index + 1)/\(quotes.count): Generating audio...")
                let audioData = try await generateSpeech(text: quote)
                try cacheAudio(data: audioData, for: quote)
                successCount += 1
                print("✅ Quote \(index + 1)/\(quotes.count): Cached successfully")
                
                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
            } catch {
                failCount += 1
                print("❌ Quote \(index + 1)/\(quotes.count): Failed to cache - \(error.localizedDescription)")
            }
        }
        
        print("🎉 Pre-cache completed:")
        print("   ✅ Success: \(successCount)")
        print("   ⏭️  Skipped: \(skipCount)")
        print("   ❌ Failed: \(failCount)")
    }
    
    // MARK: - Text-to-Speech
    
    func playTextToSpeech(text: String, onFinished: (() -> Void)? = nil) async {
        guard !text.isEmpty && text != "Loading..." else {
            print("❌ Invalid text for speech synthesis")
            onFinished?()
            return
        }
        
        self.onAudioFinished = onFinished
        
        do {
            let audioData: Data
            
            // Check if audio is cached
            if isCached(text: text) {
                print("📦 Loading cached audio for: \(text.prefix(50))...")
                audioData = try loadCachedAudio(for: text)
                print("✅ Loaded from cache")
            } else {
                // Not cached, generate from API
                guard !apiKey.isEmpty else {
                    print("❌ ElevenLabs API key not configured")
                    onFinished?()
                    return
                }
                
                print("🎵 Generating speech for: \(text.prefix(50))...")
                audioData = try await generateSpeech(text: text)
                
                // Cache the audio for future use
                do {
                    try cacheAudio(data: audioData, for: text)
                } catch {
                    print("⚠️ Failed to cache audio: \(error.localizedDescription)")
                    // Continue anyway - caching is not critical
                }
            }
            
            print("✅ Playing audio...")
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
            "model_id": "eleven_v3",
            "voice_settings": [
                "stability": 0,
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

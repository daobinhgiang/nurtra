//
//  OpenAIService.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/28/25.
//

import Foundation

@MainActor
class OpenAIService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    init() {
        // Read API key from Secrets.swift
        let key = Secrets.openAIAPIKey
        
        if !key.isEmpty && !key.hasPrefix("sk-proj-REPLACE") && !key.contains("your-api-key") {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("⚠️ Warning: OpenAI API key not configured. Please set your key in Secrets.swift")
        }
    }
    
    // MARK: - Generate Motivational Quotes
    
    func generateMotivationalQuotes(from responses: OnboardingSurveyResponses, userName: String? = nil) async throws -> [String] {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        let prompt = buildPrompt(from: responses, userName: userName)
        
        let requestBody: [String: Any] = [
            "model": "gpt-4.1-mini",
            "messages": [ 
                [
                    "role": "system",
                    "content": """
                    You are a accountability partner specializing in eating disorder recovery. Generate personalized, empowering motivational quotes with embedded ElevenLabs audio tags.
                    
                    CRITICAL STYLE REQUIREMENTS:
                    - Write quotes that sound like everyday people talking - casual, natural, and conversational
                    - Keep quotes SHORT and CONCISE (aim for 8-15 words max per quote)
                    - Use simple, everyday language - avoid formal or flowery phrases
                    - Write like a friend texting you, not a therapist giving a speech
                    - Be direct and to the point - no long explanations or elaborate metaphors
                    
                    IMPORTANT: Include ElevenLabs v3 audio tags to convey emotion and tone. Place tags BEFORE the relevant phrase or sentence they should apply to.
                    
                    Available audio tags:
                    - Emotional: [CARING] [COMPASSIONATE] [GENTLE] [HOPEFUL] [CONFIDENT] [SERIOUS] [SINCERE] [WARM] [SUPPORTIVE] [MELANCHOLIC] [CONCERNED] [OPTIMISTIC] [PROUD] [TENDER] [THOUGHTFUL] [CALM] [ENCOURAGING]
                    - Pace: [SLOW] [MEASURED] [PAUSED] [DRAMATIC PAUSE] [STEADY]
                    - Volume: [SOFT] [WHISPERING] [NORMAL] [EMPHATIC]
                    - Reactions: [SIGH] [HEAVY SIGH] [HMM]
                    
                    Example: "[CARING] [SOFT] You deserve better than this, and deep down, you know it. [PAUSED] [HOPEFUL] Tomorrow is a fresh start."
                    
                    Use tags naturally to enhance emotional delivery - don't overuse them. 1-3 tags per quote is ideal.
                    """
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.9,
            "max_tokens": 1500
        ]
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("OpenAI API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let quotes = try parseQuotes(from: data)
        return quotes
    }
    
    // MARK: - Helper Methods
    
    private func buildPrompt(from responses: OnboardingSurveyResponses, userName: String? = nil) -> String {
        let struggleDuration = responses.struggleDuration.joined(separator: ", ")
        let bingeFrequency = responses.bingeFrequency.joined(separator: ", ")
        let importanceReason = responses.importanceReason.joined(separator: ", ")
        let lifeWithoutBinge = responses.lifeWithoutBinge.joined(separator: ", ")
        let bingeThoughts = responses.bingeThoughts.joined(separator: ", ")
        let bingeTriggers = responses.bingeTriggers.joined(separator: ", ")
        let copingActivities = responses.copingActivities.joined(separator: ", ")
        let whatMattersMost = responses.whatMattersMost.joined(separator: ", ")
        let recoveryValues = responses.recoveryValues.joined(separator: ", ")
        
        let nameContext = if let name = userName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "This person's name is \(name). Use their name naturally in the quotes to make them feel personally addressed."
        } else {
            "Address them directly using 'you' since their name is not available."
        }
        
        return """
        Based on the following information about a person's binge eating recovery journey, generate exactly 10 personalized quotes that sound like they're coming from a close peer who's been there and understands. Make each quote unique, authentic, and deeply connected to their specific situation and values.
        
        \(nameContext)
        
        Their Journey:
        - Duration of struggle: \(struggleDuration)
        - Frequency of binges: \(bingeFrequency)
        - Why recovery matters to them: \(importanceReason)
        - Their vision without binge eating: \(lifeWithoutBinge)
        - Common thoughts during binges: \(bingeThoughts)
        - Triggers: \(bingeTriggers)
        - Coping activities they can do: \(copingActivities)
        - What matters most to them: \(whatMattersMost)
        - Recovery values: \(recoveryValues)
        
        Requirements:
        1. Generate exactly 10 quotes
        2. Each quote should be SHORT and CONCISE - aim for 8-15 words maximum (one brief sentence)
        3. Write like a close friend texting you - super casual, natural, everyday language
        4. Use simple, direct words - avoid formal language, complex sentences, or flowery phrases
        5. Sound like real people talk, not like motivational posters or therapy sessions
        6. Structure the quotes as follows:
           - Quotes 1-3: Guilt trip them for relapsing (but from a caring place)
             → Use audio tags like: [CARING] [CONCERNED] [SERIOUS] [GENTLE] [SOFT] [SIGH] [PAUSED]
           - Quotes 4-6: Remind them of what they value and their "why"
             → Use audio tags like: [SINCERE] [THOUGHTFUL] [WARM] [HOPEFUL] [MEASURED] [DRAMATIC PAUSE]
           - Quotes 7-8: Remind them of their specific coping activities they mentioned
             → Use audio tags like: [ENCOURAGING] [OPTIMISTIC] [CONFIDENT] [STEADY] [SUPPORTIVE]
           - Quotes 9-10: Motivate and encourage them forward
             → Use audio tags like: [HOPEFUL] [PROUD] [CONFIDENT] [OPTIMISTIC] [EMPHATIC] [WARM]
        7. Make them personal to their specific struggles, triggers, and values
        8. Use super casual, everyday language (like "you know this isn't you" or "c'mon, you got this")
        9. Reference their specific journey details naturally but briefly
        10. When their name is provided, use it naturally in some quotes (not all) to create personal connection
        11. Format as a numbered list (1. Quote 1\n2. Quote 2\n...)
        12. CRITICAL: Include 1-3 ElevenLabs audio tags per quote, placed BEFORE the words/phrases they apply to
        
        Audio Tag Examples (notice how short and casual these are):
        - "[CARING] [SOFT] Hey, you promised yourself you'd try harder today."
        - "[SIGH] [THOUGHTFUL] Remember why you started? [PAUSED] [HOPEFUL] That person's still there."
        - "[ENCOURAGING] You said meditation helps - try it now."
        - "[CONFIDENT] [EMPHATIC] You've come too far to give up now."
        
        Generate the 10 quotes now with audio tags. Keep them SHORT and CASUAL like everyday people talk:
        """
    }
    
    private func parseQuotes(from data: Data) throws -> [String] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parseError
        }
        
        // Parse numbered list format (1. Quote\n2. Quote\n...)
        let quotes = content
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Match lines starting with numbers like "1.", "2.", etc.
                if let range = trimmed.range(of: "^\\d+\\.\\s*", options: .regularExpression) {
                    let quote = String(trimmed[range.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    return quote.isEmpty ? nil : quote
                }
                return nil
            }
        
        // Ensure we have exactly 10 quotes
        guard quotes.count >= 10 else {
            print("Warning: Only received \(quotes.count) quotes from OpenAI")
            throw OpenAIError.insufficientQuotes
        }
        
        // Return first 10 quotes
        return Array(quotes.prefix(10))
    }
}

// MARK: - Error Handling

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError
    case insufficientQuotes
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not configured"
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let message):
            return "OpenAI API error (\(statusCode)): \(message)"
        case .parseError:
            return "Failed to parse OpenAI response"
        case .insufficientQuotes:
            return "Did not receive enough quotes from OpenAI"
        }
    }
}


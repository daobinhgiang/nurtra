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
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a compassionate therapist specializing in eating disorder recovery. Generate personalized, empowering motivational quotes that are unique, varied, and authentic."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.9,
            "max_tokens": 2000
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
            "This person's name is \(name). Use their name naturally in some quotes (not all) to make them feel personally addressed."
        } else {
            "Address them directly using 'you' since their name is not available."
        }
        
        return """
        Based on the following information about a person's binge eating recovery journey, generate exactly 30 personalized quotes that sound like they're coming from a close peer who's been there and understands. Make each quote unique, authentic, varied, and deeply connected to their specific situation and values. The user will see these quotes randomized, so ensure high variety and minimal repetition.
        
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
        1. Generate exactly 30 quotes - no more, no less
        2. Each quote should be exactly 1-2 sentences (keep them punchy and powerful)
        3. Write like a close friend/peer speaking casually and directly
        4. Vary the tone and approach across different quotes:
           - Quotes 1-5: Guilt trip them for relapsing (but from a caring place) - "You know this isn't you..."
           - Quotes 6-11: Remind them of what they value and their "why" - "Remember why this matters..."
           - Quotes 12-17: Remind them of their specific coping activities (exercise, meditation, creative outlets, spending time with friends, going outdoors, journaling, etc.)
           - Quotes 18-23: Motivate and encourage them forward - "You've got this..." "You're stronger than..."
           - Quotes 24-30: Mix different approaches - some tough love, some gentle encouragement, some humor, some vulnerability
        5. Make them personal to their specific struggles, triggers, and values
        6. Use varied casual, peer-to-peer language (avoid repeating the same phrases)
        7. Reference their specific journey details naturally and vary which details you reference
        8. Use their name naturally in 8-12 of the 30 quotes to create personal connection
        9. Ensure MAXIMUM VARIETY - avoid similar phrasing or messaging across quotes
        10. Include some quotes that reference:
            - Their specific triggers (if applicable)
            - Specific coping strategies they mentioned
            - Their personal values
            - Recovery timeline/journey
            - Future vision of life without binge eating
        11. Format as a numbered list (1. Quote 1\n2. Quote 2\n...30. Quote 30\n)
        
        Generate the 30 unique, varied, and interesting quotes now:
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
        
        // Ensure we have at least 30 quotes
        guard quotes.count >= 30 else {
            print("Warning: Only received \(quotes.count) quotes from OpenAI, expected at least 30")
            throw OpenAIError.insufficientQuotes
        }
        
        // Return first 30 quotes
        return Array(quotes.prefix(30))
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


# OpenAI Motivational Quotes Feature - Setup Guide

## Overview

This feature automatically generates 10 personalized motivational quotes using OpenAI's Chat API after a user completes the onboarding survey. The quotes are generated in the background and saved to Firestore.

## Implementation Summary

### Files Created
1. **`nurtra/OpenAIService.swift`** - Handles OpenAI API communication
2. **`nurtra/QuoteGenerationService.swift`** - Coordinates the quote generation flow
3. **`nurtra/Secrets.swift`** - Secure storage for API key (in .gitignore)
4. **`OPENAI_QUOTES_SETUP.md`** - This setup guide

### Files Modified
1. **`nurtra/FirestoreManager.swift`** - Added quote storage methods
2. **`nurtra/OnboardingSurveyView.swift`** - Triggers quote generation
3. **`nurtra/Info.plist`** - Added OPENAI_API_KEY reference

## Setup Instructions

### Step 1: Add Your OpenAI API Key

1. **Get your API key** from [OpenAI Platform](https://platform.openai.com/api-keys)

2. **Update `nurtra/Secrets.swift`**:
   ```swift
   enum Secrets {
       static let openAIAPIKey = "sk-your-actual-api-key-here"
   }
   ```

3. **Important Security**: `Secrets.swift` is already in `.gitignore` to prevent accidentally committing your API key

### Step 2: Update Firestore Security Rules

Add rules to allow users to read/write their user document (quotes are stored in the same document):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Step 3: Test the Feature

1. **Build and run** the app
2. **Sign up** with a new account
3. **Complete** the onboarding survey
4. **Check console logs** for quote generation and audio pre-caching:
   ```
   🎯 Starting quote generation in background...
   📝 Calling OpenAI API...
   ✨ Generated 10 quotes:
     1. [CARING] [SOFT] [Quote text]
     2. [HOPEFUL] [Quote text]
     ...
   💾 Saving quotes to Firestore...
   🎙️  Pre-caching audio for all quotes...
   🎵 Starting pre-cache for 10 quotes...
   🎙️  Quote 1/10: Generating audio...
   💾 Cached audio to: a3f8d9c2e1b5f6a7....mp3
   ✅ Quote 1/10: Cached successfully
   ...
   🎉 Pre-cache completed:
      ✅ Success: 10
      ⏭️  Skipped: 0
      ❌ Failed: 0
   ✅ Quote generation and audio pre-caching completed successfully!
   ```

5. **Verify in Firestore Console**:
   - Navigate to Firestore Database
   - Go to `users/{userId}` document
   - You should see a `motivationalQuotes` field with 10 numbered quotes (1, 2, 3, etc.)
   - Each quote should include audio tags like [CARING], [HOPEFUL], etc.
   - You should also see `motivationalQuotesGeneratedAt` timestamp

6. **Test Audio Playback**:
   - Navigate to the Craving screen
   - Audio should play **immediately** with no delay
   - Check console for `📦 Loading cached audio...` messages (not `🎵 Generating speech...`)

## How It Works

### Flow Diagram

```
User completes onboarding
         ↓
OnboardingSurveyView.submitSurvey()
         ↓
Save responses to Firestore
         ↓
QuoteGenerationService.generateQuotesInBackground() [Background Task]
         ↓
OpenAIService.generateMotivationalQuotes()
         ↓
Build personalized prompt from survey responses
         ↓
Call OpenAI Chat API (gpt-4o-mini)
         ↓
Parse 10 quotes from response (with audio tags)
         ↓
FirestoreManager.saveMotivationalQuotes()
         ↓
Save quotes to Firestore
         ↓
ElevenLabsService.preCacheAudioForQuotes() [NEW!]
         ↓
Generate audio for all 10 quotes via ElevenLabs v3
         ↓
Cache all audio files locally
         ↓
User can play quotes instantly from cache in Craving screen
```

### Key Features

1. **Non-Blocking**: Runs in background using `Task.detached`
2. **Personalized**: Uses all 8 onboarding responses to create tailored quotes
3. **ElevenLabs Audio Tags**: Quotes include emotional audio tags for expressive text-to-speech
4. **Pre-Cached Audio**: All audio files generated and cached during onboarding
5. **Instant Playback**: Audio ready before user reaches craving screen
6. **Error Handling**: Graceful failure - user not blocked if generation fails
7. **Firestore Structure**: Quotes stored in user document for easy access
8. **Logging**: Comprehensive console logs for debugging

## API Details

### OpenAI Request
- **Model**: `gpt-4o-mini`
- **Temperature**: `0.9` (for creative variation)
- **Max Tokens**: `1500` (increased to accommodate audio tags)
- **System Prompt**: Specialized therapist role for eating disorder recovery with ElevenLabs audio tag instructions

### ElevenLabs Pre-Caching
- **Triggered**: Automatically after quotes are saved to Firestore
- **Process**: Sequential generation with 0.5s delay between requests to avoid rate limits
- **Cache Location**: `~/Library/Caches/ElevenLabsAudio/`
- **File Format**: MP3 files named with SHA256 hash of quote text
- **Error Handling**: Failed audio generation doesn't block the process; will retry on first playback

### Prompt Template
The prompt includes:
- Duration of struggle
- Frequency of binges
- Importance of recovery
- Vision without binge eating
- Common thoughts during binges
- Triggers
- What matters most
- Recovery values

### Response Parsing
- Expects numbered list format (1. Quote\n2. Quote\n...)
- Extracts exactly 10 quotes
- Validates quote count before saving
- Quotes include ElevenLabs v3 audio tags like [CARING], [HOPEFUL], [SOFT], [PAUSED]

### ElevenLabs Audio Tags Integration

The quotes are generated with embedded audio tags that ElevenLabs v3 uses to add emotional expression during text-to-speech synthesis. GPT is instructed to:

1. **Place tags before the relevant phrase** they should apply to
2. **Use 1-3 tags per quote** to avoid overuse
3. **Choose appropriate tags** based on the quote type:
   - **Quotes 1-3** (caring accountability): [CARING], [CONCERNED], [SERIOUS], [GENTLE], [SOFT], [SIGH], [PAUSED]
   - **Quotes 4-6** (values reminder): [SINCERE], [THOUGHTFUL], [WARM], [HOPEFUL], [MEASURED], [DRAMATIC PAUSE]
   - **Quotes 7-8** (coping activities): [ENCOURAGING], [OPTIMISTIC], [CONFIDENT], [STEADY], [SUPPORTIVE]
   - **Quotes 9-10** (motivation): [HOPEFUL], [PROUD], [CONFIDENT], [OPTIMISTIC], [EMPHATIC], [WARM]

**Example quotes with audio tags:**
- `"[CARING] [SOFT] Hey, you promised yourself you'd try harder today."`
- `"[SIGH] [THOUGHTFUL] Remember why you started this journey? [PAUSED] [HOPEFUL] That version of you is still waiting."`
- `"[ENCOURAGING] You said meditation helps - why not take five minutes right now?"`
- `"[CONFIDENT] [EMPHATIC] You've come too far to let one moment define your entire journey."`

When these quotes are sent to ElevenLabs v3 for text-to-speech, the model interprets the tags and generates speech with the specified emotional tones, pauses, and delivery styles. This creates a more human-like, empathetic audio experience.

### Audio Pre-Caching & Quote Mapping

The audio files are automatically pre-generated during onboarding and properly mapped to quotes:

**During Onboarding (Background):**
1. OpenAI generates 10 quotes with audio tags
2. Quotes saved to Firestore
3. **ElevenLabs generates audio for all 10 quotes** (one by one with rate limit protection)
4. Each audio file cached with SHA256 hash of quote text as filename
5. All complete before user navigates away from onboarding

**During Craving Screen Playback:**
1. Quote text loaded from Firestore
2. SHA256 hash computed from quote text
3. Audio loaded instantly from local cache
4. **Zero API calls, zero latency**

**Example**:
- Quote: `"[CARING] [SOFT] You deserve better than this."`
- Cache key: `a3f8d9c2e1b5f6a7d8c9b0e1f2a3d4b5c6e7d8a9f0b1c2e3d4a5f6b7c8d9e0a1b2.mp3`
- Stored: `~/Library/Caches/ElevenLabsAudio/a3f8d9c2e1b5f6a7d8c9b0e1f2a3d4b5c6e7d8a9f0b1c2e3d4a5f6b7c8d9e0a1b2.mp3`
- First playback: Instant (already cached during onboarding)

This ensures that audio is **always ready** when users need it most - during craving moments.

## Firestore Data Structure

```
users/
  {userId}/
    - onboardingCompleted: true
    - onboardingCompletedAt: Timestamp
    - onboardingResponses: {
        struggleDuration: [...],
        bingeFrequency: [...],
        importanceReason: [...],
        lifeWithoutBinge: [...],
        bingeThoughts: [...],
        bingeTriggers: [...],
        whatMattersMost: [...],
        recoveryValues: [...]
      }
    - motivationalQuotes: {
        "1": "[CARING] [SOFT] Your first personalized quote...",
        "2": "[THOUGHTFUL] Your second personalized quote...",
        "3": "[HOPEFUL] Your third personalized quote...",
        ...
        "10": "[CONFIDENT] [EMPHATIC] Your tenth personalized quote..."
      }
    - motivationalQuotesGeneratedAt: Timestamp
```

**Benefits of this structure:**
- All user data in one document (easier to query)
- Consistent with onboardingResponses format
- Simple numbered fields (1, 2, 3, etc.)
- No subcollections needed
- Single read/write operation

## Retrieving Quotes

To display quotes in your UI later:

```swift
let firestoreManager = FirestoreManager()

do {
    let quotes = try await firestoreManager.fetchMotivationalQuotes()
    // quotes is an array of MotivationalQuote objects
    // Display in your UI
} catch {
    print("Error fetching quotes: \(error)")
}
```

## Troubleshooting

### "Missing API Key" Warning
- Ensure `Config.xcconfig` is properly configured
- Check that it's linked in Build Settings
- Verify API key is not empty or still contains placeholder

### API Errors
- **401 Unauthorized**: Check API key validity
- **429 Rate Limit**: You've exceeded OpenAI rate limits
- **500 Server Error**: OpenAI service issue, will retry later

### No Quotes Generated
- Check console logs for errors
- Verify Firestore security rules allow write access
- Ensure user is authenticated when generating quotes

### Quotes Not Appearing in Firestore
- Check Firestore security rules
- Verify user document path: `users/{userId}/motivationalQuotes`
- Look for error logs in console

## Cost Estimation

### OpenAI Costs (per user)
Using `gpt-4o-mini`:
- **Input tokens**: ~400-600 tokens (prompt with onboarding data)
- **Output tokens**: ~400-600 tokens (10 quotes with audio tags)
- **Cost per user**: ~$0.0010-0.0020 USD
- **For 1000 users**: ~$1.00-2.00 USD

### ElevenLabs Costs (per user)
- **Characters per quote**: ~100-150 (including audio tags)
- **10 quotes**: ~1,000-1,500 characters
- **Free tier**: 10,000 characters/month = ~7-10 users
- **Paid tier**: ~$0.30 per 1,000 characters = ~$0.30-0.45 per user

### Total Cost Per User
- **OpenAI**: ~$0.0015
- **ElevenLabs**: ~$0.35 (paid tier)
- **Total**: ~$0.35 per user onboarded

*After onboarding, users play audio from cache with zero additional API costs.*

*Prices as of November 2024. Check [OpenAI Pricing](https://openai.com/pricing) and [ElevenLabs Pricing](https://elevenlabs.io/pricing) for current rates.*

## Production Recommendations

### Option 1: Use Firebase Cloud Functions (Recommended)

For better security and scalability, implement as a Cloud Function:

```javascript
// functions/index.js
exports.generateQuotes = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const responses = snap.data().onboardingResponses;
    const quotes = await callOpenAI(responses);
    await saveQuotes(context.params.userId, quotes);
  });
```

**Benefits**:
- API key stays server-side
- Better rate limiting control
- Automatic retry logic
- Monitoring and logging
- No client-side API exposure

### Option 2: Keep Client-Side (Current Implementation)

If keeping client-side:
- Use Firebase Remote Config for API key
- Implement request signing
- Add usage monitoring
- Set up alerts for unusual activity

## Next Steps

1. **Build UI** to display quotes to users
2. **Add refresh feature** to regenerate quotes
3. **Implement favorites** for users to save preferred quotes
4. **Add sharing** functionality
5. **Track analytics** on quote generation success/failure

## Support

For issues or questions:
- Check console logs for detailed error messages
- Verify all setup steps are completed
- Test with a fresh user account
- Check Firestore Console for data

## Security Notes

⚠️ **IMPORTANT**: 
- Never commit `Config.xcconfig` with real API keys
- Add to `.gitignore` immediately
- For production, use Firebase Cloud Functions
- Monitor OpenAI usage in your dashboard
- Set up spending limits on OpenAI account

## ElevenLabs Audio Tags Reference

The system uses ElevenLabs v3 audio tags to create emotionally expressive text-to-speech. The tags are embedded in the generated quotes and interpreted by ElevenLabs during synthesis.

### How It Works

1. **OpenAI generates quotes** with embedded audio tags like `[CARING] [SOFT] Your quote text here`
2. **Tags are stored in Firestore** as part of the quote text
3. **ElevenLabs v3 reads the tags** when generating speech and applies the emotional tones
4. **Result**: More human-like, emotionally resonant audio playback

### Tag Categories Used

**Emotional Tone:**
- [CARING], [COMPASSIONATE], [GENTLE], [HOPEFUL], [CONFIDENT], [SERIOUS], [SINCERE], [WARM], [SUPPORTIVE], [MELANCHOLIC], [CONCERNED], [OPTIMISTIC], [PROUD], [TENDER], [THOUGHTFUL], [CALM], [ENCOURAGING]

**Pace & Timing:**
- [SLOW], [MEASURED], [PAUSED], [DRAMATIC PAUSE], [STEADY]

**Volume & Energy:**
- [SOFT], [WHISPERING], [NORMAL], [EMPHATIC]

**Non-Verbal Reactions:**
- [SIGH], [HEAVY SIGH], [HMM]

### Best Practices

- **Use 1-3 tags per quote** - Don't over-tag, it can sound unnatural
- **Place tags before the phrase** they apply to
- **Match tags to quote intent** - Use caring/gentle for accountability, hopeful/confident for motivation
- **Combine complementary tags** - e.g., [CARING] [SOFT] work well together
- **Test audio output** - Listen to generated speech to verify tags are effective

### Documentation

For the complete list of available ElevenLabs audio tags, see:
- **Emotional Tone & Attitude Tags**: ~140 tags covering all emotional states
- **Non-Verbal Reaction Tags**: ~60 tags for human sounds (sighs, laughs, etc.)
- **Volume & Energy Tags**: ~50 tags for delivery intensity
- **Pace, Rhythm & Timing Tags**: ~60 tags for speech timing

Full reference: ElevenLabs v3 documentation at `https://elevenlabs.io/docs/models#eleven-v3-alpha`


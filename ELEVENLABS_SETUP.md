# ElevenLabs Text-to-Speech Setup Guide

## Overview

This feature adds audio playback of motivational quotes using ElevenLabs' text-to-speech API. Users can click the speaker button next to "Next Quote" to hear the current quote spoken aloud.

## Implementation Summary

### Files Created
1. **`nurtra/ElevenLabsService.swift`** - Handles ElevenLabs API communication and audio playback
2. **`ELEVENLABS_SETUP.md`** - This setup guide

### Files Modified
1. **`nurtra/Secrets.swift`** - Added ElevenLabs API key and voice ID
2. **`nurtra/CravingView.swift`** - Added audio button and ElevenLabs integration

## Setup Instructions

### Step 1: Add ElevenLabsService.swift to Xcode Project

1. **Open Xcode** with your nurtra.xcodeproj
2. **Right-click** on the "nurtra" folder in the project navigator
3. **Select** "Add Files to 'nurtra'"
4. **Navigate** to the nurtra folder and select `ElevenLabsService.swift`
5. **Make sure** "Add to target: nurtra" is checked
6. **Click** "Add"

### Step 2: Get Your ElevenLabs API Key

1. **Sign up** at [ElevenLabs](https://elevenlabs.io/)
2. **Go to** your profile settings
3. **Copy** your API key from the API section

### Step 3: Update Your API Key

1. **Open** `nurtra/Secrets.swift`
2. **Replace** `"YOUR_ELEVENLABS_API_KEY_HERE"` with your actual API key:
   ```swift
   static let elevenLabsAPIKey = "your-actual-api-key-here"
   ```

### Step 4: Voice Configuration (Optional)

The default voice is Rachel (ID: `21m00Tcm4TlvDq8ikWAM`) - a calm, soothing voice perfect for motivational content.

To use a different voice:
1. **Browse voices** at [ElevenLabs Voice Library](https://elevenlabs.io/voice-library)
2. **Copy the voice ID** from your chosen voice
3. **Update** `elevenLabsVoiceID` in `Secrets.swift`

### Step 5: Test the Feature

1. **Build and run** the app
2. **Navigate** to the Craving page
3. **Tap the speaker button** next to "Next Quote"
4. **Listen** to your motivational quote!

## Features

- **High-quality speech synthesis** using ElevenLabs' Eleven v3 model (alpha)
- **Local audio caching** - audio files are saved locally after first generation
- **Smart cache management** - quotes are mapped to cached files using SHA256 hashing
- **Instant playback** - cached quotes play immediately without API calls
- **Seamless integration** with existing quote system
- **Audio controls** - automatically stops previous audio when playing new quote
- **Error handling** for network issues and API errors
- **Secure API key storage** in Secrets.swift (already in .gitignore)

## Troubleshooting

### "ElevenLabs API key not configured" Warning
- Ensure you've replaced the placeholder in `Secrets.swift`
- Check that the API key doesn't contain placeholder text

### No Audio Playback
- Check device volume and silent mode
- Verify network connection for API calls
- Check console logs for specific error messages

### API Errors
- **401 Unauthorized**: Check API key validity
- **429 Rate Limit**: You've exceeded ElevenLabs rate limits
- **500 Server Error**: ElevenLabs service issue, try again later

## Model Selection

- The app currently uses `eleven_v3` for Text-to-Speech. According to the official ElevenLabs models page, Eleven v3 (alpha) offers the most emotionally rich, expressive synthesis and supports 70+ languages, with a 3,000 character limit per request. It is not intended for real-time agent use; for ultra-low latency, consider Flash v2.5 instead.
- Reference: see ElevenLabs Models documentation (Eleven v3 alpha) at `https://elevenlabs.io/docs/models#eleven-v3-alpha`.

## Audio Tags Integration

The app uses **ElevenLabs v3 audio tags** to create emotionally expressive text-to-speech. When OpenAI generates motivational quotes, it embeds audio tags like `[CARING]`, `[HOPEFUL]`, `[SOFT]`, and `[PAUSED]` directly in the quote text.

### How It Works

1. **OpenAI generates quotes** with embedded tags: `"[CARING] [SOFT] You deserve better, and you know it."`
2. **ElevenLabsService sends the entire quote** (including tags) to the v3 API
3. **ElevenLabs v3 interprets the tags** and applies emotional tones, pacing, and volume adjustments
4. **Result**: Natural, emotionally resonant speech that sounds more human and empathetic

### Example

Without tags:
- `"You deserve better than this."`
- *(Neutral, flat delivery)*

With tags:
- `"[CARING] [SOFT] You deserve better than this. [PAUSED] [HOPEFUL] Tomorrow is a fresh start."`
- *(Caring, gentle tone with thoughtful pause, then hopeful uplift)*

### Tag Categories

The quotes use a curated subset of ElevenLabs audio tags:
- **Emotional**: [CARING], [COMPASSIONATE], [HOPEFUL], [CONFIDENT], [GENTLE], [SINCERE], [WARM], [ENCOURAGING]
- **Pace**: [SLOW], [MEASURED], [PAUSED], [DRAMATIC PAUSE], [STEADY]
- **Volume**: [SOFT], [WHISPERING], [NORMAL], [EMPHATIC]
- **Reactions**: [SIGH], [HEAVY SIGH], [HMM]

**Note**: Audio tags are automatically hidden from users in the UI - they only see the clean quote text, while the audio system uses the full text with tags for expressive speech generation.

For more details on audio tag implementation, see `OPENAI_QUOTES_SETUP.md`.

## Audio Caching System

The app implements intelligent local audio pre-caching to optimize performance and reduce API costs:

### How It Works

**During Onboarding:**
1. User completes onboarding survey
2. OpenAI generates 10 personalized quotes with audio tags
3. Quotes are saved to Firestore
4. **ElevenLabs automatically generates audio for all 10 quotes** (runs in background)
5. All audio files are cached locally before user finishes onboarding

**In Craving Screen:**
1. User enters craving screen
2. Quotes are loaded from Firestore
3. **Audio tags are stripped from display text** - users see clean quotes
4. **Audio plays instantly from local cache** with full audio tags - no API calls, no waiting!

### Cache Details

- **Location**: `~/Library/Caches/ElevenLabsAudio/`
- **File naming**: SHA256 hash of quote text (ensures unique mapping)
- **Format**: MP3 files
- **Persistence**: Cached across app sessions until manually cleared or iOS clears cache

### Benefits

- **Zero latency** - all audio ready before user reaches craving screen
- **Perfect user experience** - instant playback from the very first quote
- **No network calls** during craving moments
- **Reduced API costs** - 10 quotes = 10 API calls during onboarding, then zero forever
- **Offline support** - works without internet after onboarding
- **Automatic mapping** - quotes with audio tags are properly matched to cached files
- **Background processing** - doesn't slow down onboarding UI

### Cache Management

The `ElevenLabsService` provides cache management:

```swift
// Clear all cached audio (useful for testing or freeing space)
elevenLabsService.clearAudioCache()
```

**Note**: iOS may automatically clear cache if storage is low.

## API Usage & Costs

- **Free tier**: 10,000 characters per month
- **Paid plans**: Available for higher usage
- **Character count**: Each quote uses ~50-200 characters depending on length (including audio tags)
- **Per-user cost**: ~1,000-2,000 characters total (10 quotes generated once during onboarding)
- **Cost savings**: Audio pre-cached during onboarding, then zero API calls forever
- **Efficiency**: New user = 10 API calls during onboarding, then local playback only

### Example Cost Calculation

- Average quote: 100 characters (with tags)
- 10 quotes per user: 1,000 characters
- Free tier: 10,000 characters/month
- **You can onboard ~10 users/month on free tier**, with unlimited playback for all users

## Security Notes

- API key is stored in `Secrets.swift` which is in `.gitignore`
- Never commit your actual API key to version control
- ElevenLabs API calls are made over HTTPS

## Future Enhancements

Potential improvements you could add:
- **Voice selection** in app settings
- **Playback controls** (pause/resume)
- **Speed/pitch adjustment** options
- **Cache size monitoring** and automatic cleanup
- **Pre-caching** all quotes on app launch for completely offline experience

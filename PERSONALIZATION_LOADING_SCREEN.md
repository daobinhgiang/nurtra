# Personalization Loading Screen

## Overview
After completing the onboarding survey, users will see a loading screen while their personalized motivational quotes are being generated and audio files are being saved from the ElevenLabs API.

## What Was Implemented

### 1. New Loading Screen Component
**File:** `nurtra/PersonalizationLoadingView.swift`

A beautiful, minimalist loading screen featuring:
- **Title:** "Personalizing your experience"
- **Progress Bar:** Visual progress indicator with smooth animations
- **Percentage Display:** Large, bold number showing completion percentage (0-100%)
- **Status Text:** Shows "X of 10 audio files generated"
- **Loading Indicator:** Spinner at the bottom

### 2. Progress Tracking in ElevenLabsService
**File:** `nurtra/ElevenLabsService.swift`

Modified the `preCacheAudioForQuotes()` method to include a progress callback:
- Accepts an optional `progressCallback` parameter: `((Int, Int) -> Void)?`
- Calls the callback after each audio file is generated: `progressCallback?(completed, total)`
- Works for both successful generations and skipped/cached files

### 3. Progress Reporting in QuoteGenerationService
**File:** `nurtra/QuoteGenerationService.swift`

Updated `generateAndSaveQuotes()` to pass progress through:
- Accepts an optional `progressCallback` parameter
- Forwards the callback to `elevenLabsService.preCacheAudioForQuotes()`
- Enables the service to report progress up the chain

### 4. Integration in OnboardingSurveyView
**File:** `nurtra/OnboardingSurveyView.swift`

Modified the survey submission flow:
1. When user completes step 8 (survey), the survey data is saved to Firestore
2. **Loading screen is shown** with `showPersonalizationLoading = true`
3. Quote generation begins with progress tracking
4. For each of the 10 quotes that gets its audio generated/saved:
   - Progress callback updates: `personalizationCompleted`, `personalizationTotal`, `personalizationProgress`
   - Each quote = 10% progress (1/10 = 10%, 2/10 = 20%, etc.)
5. After all quotes are complete, loading screen fades out
6. User proceeds to step 9 (App Blocking explanation)

## User Experience Flow

```
Step 8: Survey → Click "Continue" 
    ↓
Saving survey responses...
    ↓
[LOADING SCREEN APPEARS]
"Personalizing your experience"
Progress: 0% → 10% → 20% → ... → 100%
"X of 10 audio files generated"
    ↓
[LOADING SCREEN FADES OUT]
    ↓
Step 9: App Blocking Explanation
```

## Key Features

- **Real-time Progress:** Updates as each audio file is generated
- **Smooth Animations:** Progress bar animates with easeInOut transitions
- **Non-blocking:** All operations happen on background threads
- **Error Handling:** Progress updates even if some files fail or are skipped
- **Accurate Percentage:** Always shows actual completion (completed/total × 100)

## Technical Details

- **Total Quotes:** 10 (configured in system)
- **Each Quote:** 10% of total progress
- **Update Frequency:** After each audio file completes
- **Thread Safety:** Uses `@MainActor` for UI updates
- **Animation Duration:** 0.3 seconds for progress bar updates

## Testing

To test this feature:
1. Complete the onboarding survey (steps 0-8)
2. Click "Continue" on step 8
3. You should see the loading screen appear
4. Watch the progress bar fill from 0% to 100%
5. The screen will automatically dismiss and proceed to step 9

## Notes

- The loading screen appears **after** the survey is saved to Firestore
- It tracks **only** the audio file generation progress (the slowest part)
- If audio files are already cached, they count toward progress immediately
- The screen uses a white background to stand out from the rest of the flow


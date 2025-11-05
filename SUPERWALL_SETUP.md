# 🏪 Superwall Paywall Integration Guide

## Overview

Superwall is integrated into the Nurtra app to manage in-app purchases and paywall displays. The system automatically handles subscription status management and provides easy-to-use methods for triggering paywalls throughout the app.

## Architecture

### Components

1. **SubscriptionManager** (`nurtra/SubscriptionManager.swift`)
   - Manages subscription state
   - Listens to Superwall subscription status changes
   - Provides methods to show paywalls and register purchases

2. **AuthenticationManager Updates** (`nurtra/AuthenticationManager.swift`)
   - Updates Superwall user attributes when users sign in/out
   - Resets Superwall when users sign out
   - Passes user information to Superwall for targeting

3. **AppDelegate Configuration** (`nurtra/nurtraApp.swift`)
   - Initializes Superwall with the API key from `Secrets.swift`
   - Sets up initial user attributes

## Setup Steps Completed

✅ Added SuperwallKit framework via Swift Package Manager
✅ Created `SubscriptionManager` class  
✅ Configured Superwall in AppDelegate
✅ Updated AuthenticationManager to sync with Superwall
✅ Added subscription status UI to Settings
✅ Integrated paywall triggers

## API Key Configuration

The Superwall API key is stored securely in `nurtra/Secrets.swift`:

```swift
static let superwallAPIKey = "pk_d97c69e785c502e76d6d0d4180c53afd769f3449ed70236d"
```

⚠️ **Security Note**: Never commit API keys to version control. The `.gitignore` file should already exclude `Secrets.swift` from commits.

## Usage

### 1. Access Subscription Status

In any view, access the subscription manager from the environment:

```swift
@EnvironmentObject var subscriptionManager: SubscriptionManager

var body: some View {
    if subscriptionManager.isSubscribed {
        // Show premium content
    } else {
        // Show free content or upgrade prompt
    }
}
```

### 2. Show a Paywall

Trigger a paywall for a specific feature:

```swift
Button(action: {
    subscriptionManager.showPaywall(for: "feature_name")
}) {
    Text("Upgrade to Premium")
}
```

Common paywall triggers for Nurtra:
- `"settings_premium"` - From settings screen
- `"premium_features"` - For access to premium features
- `"app_launch"` - On first app launch
- `"advanced_timer"` - For advanced timer features
- `"custom_quotes"` - For personalized quote generation

### 3. Check Subscription Status

```swift
let isSubscribed = subscriptionManager.isSubscribed
let status = subscriptionManager.subscriptionStatus

// Possible statuses: .active, .inactive, .unknown
```

### 4. Register a Purchase

After a successful purchase:

```swift
subscriptionManager.registerPurchase(
    productId: "com.psycholabs.nurtra.premium",
    transactionId: transaction.id
)
```

## Superwall Dashboard Configuration

1. Go to [Superwall Dashboard](https://dashboard.superwall.com)
2. Log in with your account
3. Navigate to your Nurtra app project
4. Create paywall campaigns with specific triggers

### Setting Up Paywall Campaigns

For each trigger (e.g., `"settings_premium"`):

1. Create a new campaign
2. Set the trigger name to match your code (e.g., `settings_premium`)
3. Design your paywall with:
   - Subscription plans to offer
   - Trial options
   - Call-to-action buttons
   - Pricing tiers
4. Configure A/B testing if desired
5. Deploy the campaign

## User Attributes Sent to Superwall

The following user information is sent to Superwall for targeting:

```swift
[
    "userId": user.uid,
    "email": user.email,
    "isAuthenticated": bool,
    "needsOnboarding": bool,
    "overcomeCount": int,
    "lastLogin": timestamp
]
```

This allows Superwall to show targeted paywalls based on user behavior.

## Implementation Examples

### Example 1: Premium Feature Gate

```swift
struct PremiumFeatureView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        if subscriptionManager.isSubscribed {
            AdvancedTimerFeatureView()
        } else {
            VStack(spacing: 16) {
                Text("Advanced Timer Features")
                    .font(.headline)
                Text("Unlock powerful timer customization with Premium")
                    .font(.caption)
                
                Button(action: {
                    subscriptionManager.showPaywall(for: "advanced_timer")
                }) {
                    Text("Upgrade to Premium")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}
```

### Example 2: Settings Upgrade Button

Already implemented in `SettingsView`:

```swift
if !subscriptionManager.isSubscribed {
    Button(action: {
        subscriptionManager.showPaywall(for: "settings_premium")
    }) {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
            Text("Upgrade to Premium")
                .foregroundColor(.blue)
            Spacer()
        }
    }
}
```

### Example 3: On App Launch (Optional)

In `ContentView` or main app view:

```swift
.onAppear {
    // Show paywall on first launch after onboarding
    if authManager.isAuthenticated && !authManager.needsOnboarding {
        // Optional: Show promotion paywall
        // subscriptionManager.showPaywall(for: "app_launch")
    }
}
```

## Monetization Strategy Recommendations

### For Nurtra Binge Recovery App

Consider offering Premium with:

1. **Ad-Free Experience** - No ads in the app
2. **Advanced Timer Features**
   - Custom time intervals
   - Timer templates
   - Timer history analytics
3. **AI-Powered Features**
   - Personalized motivational quotes
   - Custom coping strategies
   - Real-time craving assistance
4. **Enhanced Analytics**
   - Detailed recovery statistics
   - Progress reports
   - Trend analysis
5. **Priority Support**
   - Faster email support response
   - Direct messaging with coaches

### Pricing Tiers Example

- **Free**: Basic timer, generic quotes, limited history
- **Premium**: $4.99/month or $34.99/year
  - All free features
  - Ad-free
  - Advanced timer
  - Personalized AI quotes
  - Enhanced analytics
  - Priority support

## Testing

### Test in Sandbox Mode

1. In Superwall dashboard, enable sandbox mode
2. Use test user accounts to preview paywalls
3. Paywalls will show but won't charge real money

### Testing with Simulator

1. Run the app in the iOS simulator
2. Trigger paywalls using the `showPaywall(for:)` method
3. Test all paywall flows without real transactions

### Device Testing

1. Run on a physical device
2. Test with a real Apple ID
3. Complete test purchases (not charged due to TestFlight/sandbox)

## Troubleshooting

### Paywall Not Showing

- ✅ Check Superwall API key is correct in `Secrets.swift`
- ✅ Verify trigger name matches dashboard campaign name
- ✅ Check internet connection
- ✅ Ensure user is authenticated

### Subscription Status Not Updating

- ✅ Clear app cache and reinstall
- ✅ Check user attributes are being sent correctly
- ✅ Verify purchase was completed successfully
- ✅ Check Superwall dashboard for errors

### Build Errors

- ✅ Ensure SuperwallKit is added to project dependencies
- ✅ Check Swift version is 5.0 or higher
- ✅ Verify iOS deployment target is 13.0 or higher

## Important Notes

⚠️ **Security**:
- API key is stored in `Secrets.swift` which should be in `.gitignore`
- Never hardcode API keys in production code
- Always use sandbox/test mode during development

⚠️ **User Experience**:
- Don't show paywalls too frequently
- Show value before asking for payment
- Allow users to try key features before upgrading
- Make it easy to restore purchases

⚠️ **Testing**:
- Use the Superwall dashboard to test campaign changes
- Test on both iOS simulator and physical devices
- Verify all paywall triggers work correctly before release

## Analytics

Superwall automatically tracks:
- Paywall impressions
- Paywall conversions
- Purchase success/failure
- User cohort behavior
- A/B test results

Monitor these metrics in the Superwall dashboard to optimize paywall performance.

## Support

- [Superwall Documentation](https://docs.superwall.com)
- [Superwall Dashboard](https://dashboard.superwall.com)
- [iOS SDK GitHub](https://github.com/superwall/superwall-ios)

For integration issues specific to Nurtra, check:
- `nurtra/SubscriptionManager.swift`
- `nurtra/AuthenticationManager.swift`
- `nurtra/nurtraApp.swift` (AppDelegate configuration)

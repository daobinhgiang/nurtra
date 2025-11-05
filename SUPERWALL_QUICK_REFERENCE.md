# Superwall Quick Reference

## 🚀 Quick Start

### Show a Paywall
```swift
@EnvironmentObject var subscriptionManager: SubscriptionManager

Button(action: {
    subscriptionManager.showPaywall(for: "feature_name")
}) {
    Text("Unlock Premium")
}
```

### Check if User is Premium
```swift
if subscriptionManager.isSubscribed {
    // Show premium content
}
```

### Add Subscription Status to UI
```swift
@EnvironmentObject var subscriptionManager: SubscriptionManager

var body: some View {
    HStack {
        Image(systemName: subscriptionManager.isSubscribed ? "star.fill" : "star")
            .foregroundColor(subscriptionManager.isSubscribed ? .yellow : .gray)
        Text(subscriptionManager.isSubscribed ? "Premium" : "Free")
    }
}
```

---

## 📋 Common Paywall Triggers for Nurtra

| Trigger | When to Use | Example |
|---------|-----------|---------|
| `settings_premium` | Settings screen upgrade | Settings → Upgrade button |
| `advanced_timer` | Advanced timer features | Timer customization |
| `custom_quotes` | Personalized quotes | AI-powered quotes |
| `app_launch` | Welcome back | After login |
| `premium_features` | General premium features | Feature access |
| `analytics` | Advanced analytics | Progress reports |
| `priority_support` | Support features | Chat support |

---

## 🎯 Common Implementation Patterns

### Pattern 1: Feature Gate
```swift
struct AdvancedFeatureView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        if subscriptionManager.isSubscribed {
            PremiumContent()
        } else {
            FreemiumContent()
                .overlay(alignment: .bottom) {
                    Button(action: {
                        subscriptionManager.showPaywall(for: "advanced_feature")
                    }) {
                        Text("Unlock with Premium")
                    }
                }
        }
    }
}
```

### Pattern 2: Action Gate
```swift
struct TimerView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    func handlePremiumAction() {
        if !subscriptionManager.isSubscribed {
            subscriptionManager.showPaywall(for: "advanced_timer")
        } else {
            // Perform premium action
            performAdvancedAction()
        }
    }
    
    var body: some View {
        Button(action: handlePremiumAction) {
            Text("Custom Timer Setup")
        }
    }
}
```

### Pattern 3: Settings Section
```swift
struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        List {
            Section("Subscription") {
                SubscriptionStatusRow()
                
                if !subscriptionManager.isSubscribed {
                    Button(action: {
                        subscriptionManager.showPaywall(for: "settings_premium")
                    }) {
                        HStack {
                            Image(systemName: "crown")
                            Text("Upgrade to Premium")
                        }
                    }
                }
            }
        }
    }
}
```

---

## 🔧 Advanced Usage

### Monitor Subscription Changes
```swift
.onReceive(subscriptionManager.$isSubscribed) { isSubscribed in
    if isSubscribed {
        print("User upgraded to premium!")
        // Sync with server, update analytics, etc.
    }
}
```

### Register a Purchase Manually
```swift
func handlePurchaseCompletion(productId: String, transactionId: String) {
    subscriptionManager.registerPurchase(
        productId: productId,
        transactionId: transactionId
    )
}
```

### Check Subscription Status at Launch
```swift
.task {
    await subscriptionManager.checkSubscriptionStatus()
}
```

---

## 🌍 Setting Up in Superwall Dashboard

### Step 1: Create a Campaign
1. Go to Dashboard
2. Click "Create Campaign"
3. Enter trigger name: `advanced_timer`
4. Choose "Paywall" template

### Step 2: Design Paywall
1. Select paywall template
2. Add subscription plans
3. Set pricing and trial
4. Customize CTA buttons

### Step 3: Deploy
1. Review campaign
2. Click "Publish"
3. Campaign is live in your app

---

## 🧪 Testing Checklist

- [ ] Install app on test device
- [ ] Log in with test account
- [ ] Trigger paywall with `subscriptionManager.showPaywall(for: "test")`
- [ ] Verify paywall displays
- [ ] Test restore purchases if available
- [ ] Confirm subscription status updates
- [ ] Verify all UI gates work correctly
- [ ] Test logout and re-login

---

## ⚠️ Common Issues & Solutions

### Paywall Not Showing
```swift
// Ensure:
// 1. User is authenticated
if !authManager.isAuthenticated {
    return // Can't show paywall to anonymous users
}

// 2. API key is correct in Secrets.swift
let key = Secrets.superwallAPIKey // Should be valid

// 3. Trigger name matches dashboard
subscriptionManager.showPaywall(for: "exact_trigger_name")
```

### Subscription Status Not Updating
```swift
// Force refresh subscription status
await subscriptionManager.checkSubscriptionStatus()

// Check if attributes are being sent
// Debug: Check Superwall dashboard user events
```

### Build Errors
```
Error: No such module 'SuperwallKit'
Solution: Add SuperwallKit via SPM in Xcode
```

---

## 📊 Monitoring

In Superwall Dashboard:
1. **Events**: Track paywall shows, conversions, purchases
2. **Analytics**: View funnel metrics
3. **Users**: See user cohorts and attributes
4. **Revenue**: Monitor MRR and ARR

---

## 🎨 UI Examples

### Minimal Premium Badge
```swift
HStack {
    Text("Premium Feature")
    if subscriptionManager.isSubscribed {
        Badge("PRO")
    }
}
```

### Premium Button Variant
```swift
Button(action: { subscriptionManager.showPaywall(for: "feature") }) {
    HStack {
        Image(systemName: "crown.fill")
        Text("Upgrade")
    }
    .foregroundColor(.yellow)
}
```

### Subscription Status Card
```swift
VStack(alignment: .leading) {
    HStack {
        Image(systemName: subscriptionManager.isSubscribed ? 
              "checkmark.circle.fill" : "circle")
        Text(subscriptionManager.isSubscribed ? "Active" : "Inactive")
    }
    Text("Subscription Status")
        .font(.caption)
        .foregroundColor(.secondary)
}
.padding()
.background(.gray.opacity(0.1))
.cornerRadius(8)
```

---

## 📞 Need Help?

- Check `SUPERWALL_SETUP.md` for detailed documentation
- Review `SubscriptionManager.swift` source code
- Visit [Superwall Docs](https://docs.superwall.com)
- Check [iOS SDK GitHub](https://github.com/superwall/superwall-ios)

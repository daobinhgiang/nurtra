# App Store Subscription Compliance

## Overview

This document explains how the app complies with Apple's requirements for apps offering auto-renewable subscriptions.

## Apple's Requirements

Apps offering auto-renewable subscriptions must include the following information **in the app binary**:

1. ✅ **Title of auto-renewing subscription** (may be the same as the in-app purchase product name)
2. ✅ **Length of subscription** (e.g., weekly, monthly, annual)
3. ✅ **Price of subscription**, and price per unit if appropriate
4. ✅ **Functional links to the Privacy Policy and Terms of Use (EULA)**

## Implementation

### 1. Settings View (`nurtra/ContentView.swift`)

The Settings view now includes:

#### Subscription Plans Section
- Dynamically loads subscription products from App Store using StoreKit 2
- Displays each product's:
  - **Title** (from App Store Connect product name)
  - **Duration** (automatically formatted, e.g., "1 Month", "1 Year")
  - **Price** (in user's local currency)
  - **Price per month** (calculated for yearly subscriptions)
- Shows required disclosure footer about auto-renewal

#### Legal Section
- **Privacy Policy** link: Opens `https://nurtra.app/privacy-policy`
- **Terms of Use (EULA)** link: Opens Apple's standard EULA

### 2. SubscriptionManager (`nurtra/SubscriptionManager.swift`)

Enhanced to:
- Load subscription products from App Store using StoreKit 2
- Store products in `@Published var availableProducts: [Product]`
- Automatically sync with Superwall for subscription status
- Sort products by price (monthly first, then yearly)

### 3. Product IDs

The app uses these product identifiers (must match App Store Connect):

```swift
"com.psycholabs.nurtra.premium.monthly"
"com.psycholabs.nurtra.premium.yearly"
```

## App Store Connect Configuration

### Step 1: Create In-App Purchase Products

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → **Subscriptions**
3. Create a new subscription group (if not exists)
4. Add two subscription products:

#### Monthly Subscription
- **Product ID**: `com.psycholabs.nurtra.premium.monthly`
- **Reference Name**: Nurtra Premium - Monthly
- **Subscription Duration**: 1 Month
- **Price**: Set your monthly price (e.g., $19.99)

#### Yearly Subscription
- **Product ID**: `com.psycholabs.nurtra.premium.yearly`
- **Reference Name**: Nurtra Premium - Yearly
- **Subscription Duration**: 1 Year
- **Price**: Set your yearly price (e.g., $99.99)

### Step 2: Configure Subscription Group Settings

1. Add **Subscription Group Display Name** (appears in App Store)
2. Upload **App Store Promotional Image** (1024x1024)

### Step 3: Add Required Metadata

For each subscription product:
1. **Subscription Display Name**: The name users see (e.g., "Nurtra Premium")
2. **Description**: What the subscription includes
3. **Promotional Offer** (optional): Free trial, introductory pricing, etc.

### Step 4: App Metadata (Required!)

In App Store Connect → **App Information**:

1. **Privacy Policy URL**: `https://nurtra.app/privacy-policy`
2. **Terms of Use (EULA)**: 
   - If using custom EULA: Upload in App Store Connect
   - If using Apple's standard EULA: Add this to App Description:
     ```
     This application is governed by the Apple Standard End User License Agreement (EULA):
     https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
     ```

## Testing

### Local Testing (Xcode)

1. Add StoreKit Configuration File (if not exists):
   - File → New → File → StoreKit Configuration File
   - Add your subscription products with matching product IDs
   
2. Run app in simulator
3. Go to Settings → Should see subscription plans loaded

### Sandbox Testing

1. Create sandbox tester accounts in App Store Connect
2. Sign out of App Store on device
3. Build and install app on device
4. Navigate to Settings → Verify products display correctly
5. Trigger paywall → Complete test purchase

### Production Verification

Before submitting to App Review:
1. ✅ Verify subscription plans appear in Settings
2. ✅ Verify Privacy Policy link opens correctly
3. ✅ Verify Terms of Use link opens correctly
4. ✅ Verify prices display in correct currency
5. ✅ Verify subscription duration displays correctly
6. ✅ Verify auto-renewal disclosure is visible

## Superwall Integration

The app uses Superwall for paywall presentation, which is fully compatible with this implementation:

1. **Superwall handles purchases** through StoreKit automatically
2. **SubscriptionManager syncs status** via `Superwall.shared.$subscriptionStatus`
3. **Products are fetched directly** from App Store using StoreKit 2
4. **No conflicts** - Both systems work together seamlessly

### Superwall Dashboard Setup

1. Go to [Superwall Dashboard](https://dashboard.superwall.com)
2. Ensure products are configured:
   - Product ID: `com.psycholabs.nurtra.premium.monthly`
   - Product ID: `com.psycholabs.nurtra.premium.yearly`
3. Design paywall campaigns
4. Set up triggers (e.g., `campaign_trigger`, `settings_change_plan`)

## Common Issues & Solutions

### Products Not Loading

**Problem**: `availableProducts` is empty in Settings

**Solutions**:
1. Verify product IDs in `SubscriptionManager.swift` match App Store Connect exactly
2. Ensure products are "Ready to Submit" in App Store Connect
3. Check agreements are signed in App Store Connect
4. Wait 24 hours after creating products (propagation delay)
5. Clear Derived Data in Xcode

### Prices Not Displaying Correctly

**Problem**: Prices show wrong currency or format

**Solution**: StoreKit 2 automatically handles localization. Ensure device/simulator region settings are correct.

### Subscription Status Not Syncing

**Problem**: User subscribes but `isSubscribed` stays false

**Solutions**:
1. Verify Superwall API key is correct
2. Check Firebase/Superwall configuration
3. Ensure transaction is completed
4. Test in production build (not debug)

## Code References

### Loading Products
```swift
// In SubscriptionManager.swift
func loadProducts() async {
    let products = try await Product.products(for: productIDs)
    self.availableProducts = products.sorted { $0.price < $1.price }
}
```

### Displaying Products
```swift
// In ContentView.swift - SettingsView
ForEach(subscriptionManager.availableProducts, id: \.id) { product in
    VStack(alignment: .leading) {
        Text(product.displayName)
        Text(product.subscription?.subscriptionPeriod.localizedDescription ?? "N/A")
        Text(product.displayPrice)
    }
}
```

### Checking Subscription Status
```swift
// Anywhere in the app
@EnvironmentObject var subscriptionManager: SubscriptionManager

if subscriptionManager.isSubscribed {
    // Show premium content
}
```

## Review Submission Checklist

Before submitting to App Review, ensure:

- [ ] Product IDs in code match App Store Connect
- [ ] Products are approved and "Ready to Submit" in App Store Connect
- [ ] Privacy Policy URL is accessible and up-to-date
- [ ] Terms of Use (EULA) link is functional
- [ ] Subscription plans section appears in Settings
- [ ] All required information displays correctly (title, duration, price)
- [ ] Auto-renewal disclosure is visible
- [ ] App metadata includes EULA reference
- [ ] Tested on real device with sandbox account
- [ ] Screenshots show subscription features
- [ ] App Description mentions subscription pricing

## References

- [App Store Review Guidelines - Section 3.1.2](https://developer.apple.com/app-store/review/guidelines/#business)
- [In-App Purchase Implementation Guide](https://developer.apple.com/in-app-purchase/)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [Superwall Documentation](https://docs.superwall.com/)


#!/bin/bash

# Deployment script for Nurtra Cloud Functions
# Run this after setting up Firebase CLI and configuring OpenAI API key

echo "🚀 Deploying Nurtra Cloud Functions..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please run:"
    echo "   firebase login"
    exit 1
fi

echo "✅ Logged in to Firebase"

# Extract OpenAI API key from Secrets.swift
echo ""pse
echo "🔑 Extracting OpenAI API key from Secrets.swift..."

# Path to Secrets.swift file
SECRETS_FILE="../nurtra/Secrets.swift"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ Secrets.swift not found at $SECRETS_FILE"
    echo "   Please ensure the file exists and contains your OpenAI API key"
    exit 1
fi

# Extract API key using grep and sed
API_KEY=$(grep 'static let openAIAPIKey' "$SECRETS_FILE" | sed 's/.*= "\(.*\)".*/\1/')

if [ -z "$API_KEY" ] || [ "$API_KEY" = "sk-proj-REPLACE" ] || [[ "$API_KEY" == *"your-api-key"* ]]; then
    echo "❌ Invalid or placeholder API key found in Secrets.swift"
    echo "   Please update the openAIAPIKey value in $SECRETS_FILE"
    exit 1
fi

echo "✅ API key extracted successfully"

# Configure Firebase with the extracted API key
echo "🔧 Configuring Firebase with API key..."
firebase functions:config:set openai.key="$API_KEY"

if [ $? -eq 0 ]; then
    echo "✅ OpenAI API key configured successfully"
else
    echo "❌ Failed to configure API key"
    exit 1
fi

# Install dependencies if needed
echo ""
echo "📦 Checking dependencies..."
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
else
    echo "✅ Dependencies already installed"
fi

# Deploy functions
echo ""
echo "🚀 Deploying functions..."
firebase deploy --only functions

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📱 Next steps:"
echo "1. Build and run the iOS app on a physical device"
echo "2. Ensure notifications are enabled in Settings"
echo "3. Tap 'Test Motivational Push' button on home screen"
echo "4. Check for the push notification!"
echo ""
echo "📊 View logs with: firebase functions:log"
echo "🔍 Monitor in Firebase Console: https://console.firebase.google.com/"


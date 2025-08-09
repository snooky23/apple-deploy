#!/bin/bash

# Temporary deployment script that skips TestFlight API queries
# This bypasses the hanging issue while using local build numbers

echo "🚀 iOS Local Deployment (Bypass TestFlight API)"
echo "=============================================="

# Force local build number increment
cd template_swiftui

# Get current build number from project
CURRENT_BUILD=$(agvtool vers -terse)
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "📱 Current build: $CURRENT_BUILD"
echo "📱 New build: $NEW_BUILD"

# Update build number
agvtool new-version -all $NEW_BUILD

# Run FastLane with local parameters
fastlane build_and_upload \
    app_identifier:"com.yourcompany.yourapp" \
    app_name:"Voice Forms" \
    apple_id:"your-developer@email.com" \
    team_id:"YOUR_TEAM_ID" \
    api_key_path:"apple_info/AuthKey_YOUR_KEY_ID.p8" \
    api_key_id:"YOUR_KEY_ID" \
    api_issuer_id:"12345678-1234-1234-1234-123456789012" \
    scheme:"template_swiftui" \
    configuration:"Release" \
    p12_password:"VoiceForms2024!" \
    skip_testflight_query:"true"

echo "🎉 Local deployment completed!"
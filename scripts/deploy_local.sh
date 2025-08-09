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
    app_identifier:"com.voiceforms" \
    app_name:"Voice Forms" \
    apple_id:"perchik.omer@gmail.com" \
    team_id:"NA5574MSN5" \
    api_key_path:"apple_info/AuthKey_ZLDUP533YR.p8" \
    api_key_id:"ZLDUP533YR" \
    api_issuer_id:"63cb40ec-3fb4-4e64-b8f9-1b10996adce6" \
    scheme:"template_swiftui" \
    configuration:"Release" \
    p12_password:"VoiceForms2024!" \
    skip_testflight_query:"true"

echo "🎉 Local deployment completed!"
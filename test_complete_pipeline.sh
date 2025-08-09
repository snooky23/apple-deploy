#!/bin/bash

# iOS Publishing Automation Platform - Complete Pipeline Test
# This script demonstrates the full end-to-end TestFlight publishing capability

echo "🚀 iOS Publishing Automation Platform - Complete Pipeline Test"
echo "=============================================================="
echo ""

# Configuration
APP_IDENTIFIER="com.voiceforms"
APPLE_ID="perchik.omer@gmail.com"
TEAM_ID="NA5574MSN5"
API_KEY_PATH="../certificates/AuthKey_ZLDUP533YR.p8"
API_KEY_ID="ZLDUP533YR"
API_ISSUER_ID="63cb40ec-3fb4-4e64-b8f9-1b10996adce6"
APP_NAME="Voice Forms"
SCHEME="Test"
CONFIGURATION="Release"

echo "📋 Configuration:"
echo "   • App Identifier: $APP_IDENTIFIER"
echo "   • Apple ID: $APPLE_ID"
echo "   • Team ID: $TEAM_ID"
echo "   • App Name: $APP_NAME"
echo "   • Scheme: $SCHEME"
echo ""

# Navigate to app directory
cd app

echo "🔐 Step 1: Certificate & Profile Setup"
echo "======================================"
fastlane setup_certificates \
  app_identifier:$APP_IDENTIFIER \
  apple_id:$APPLE_ID \
  team_id:$TEAM_ID \
  api_key_path:$API_KEY_PATH \
  api_key_id:$API_KEY_ID \
  api_issuer_id:$API_ISSUER_ID \
  app_name:"$APP_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Certificate setup completed successfully!"
else
    echo "❌ Certificate setup failed"
    exit 1
fi

echo ""
echo "🔨 Step 2: Complete Build & TestFlight Upload"
echo "=============================================="
fastlane build_and_upload \
  app_identifier:$APP_IDENTIFIER \
  apple_id:$APPLE_ID \
  team_id:$TEAM_ID \
  api_key_path:$API_KEY_PATH \
  api_key_id:$API_KEY_ID \
  api_issuer_id:$API_ISSUER_ID \
  app_name:"$APP_NAME" \
  scheme:$SCHEME \
  configuration:$CONFIGURATION

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS: Complete iOS Publishing Pipeline Executed!"
    echo "======================================================"
    echo "✅ Certificate & Provisioning Profile Setup: COMPLETE"
    echo "✅ iOS App Build with Manual Code Signing: COMPLETE"
    echo "✅ IPA Export for App Store Distribution: COMPLETE"
    echo "✅ TestFlight Upload: COMPLETE"
    echo ""
    echo "📱 Your app is now processing on TestFlight!"
    echo "🔗 Check status at: https://appstoreconnect.apple.com"
    echo ""
    echo "🏆 iOS Publishing Automation Platform: PRODUCTION READY!"
else
    echo "❌ Build and upload failed"
    exit 1
fi
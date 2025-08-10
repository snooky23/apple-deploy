# 📋 Apple Deploy Platform - Complete Setup Guide v2.10.0

<div align="center">

![Setup Guide](https://img.shields.io/badge/Setup-Guide-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-2.10.0-blue?style=for-the-badge)
![Production Ready](https://img.shields.io/badge/Production-Ready-brightgreen?style=for-the-badge)

**Complete setup guide from Apple Developer Account to first TestFlight deployment**  
*Comprehensive instructions for solo developers and enterprise teams*

</div>

---

## 🎯 Overview

**✅ Platform Status**: FULLY OPERATIONAL with Enhanced Clean Architecture (v2.10.0)

This guide provides **complete step-by-step instructions** for setting up the Apple Deploy Platform. Whether you're a solo developer or setting up enterprise team infrastructure, this guide covers everything you need.

### ⏱️ **Time Investment**
- **Solo Developer**: ~15 minutes for complete setup (with Homebrew)
- **Team Lead (First Time)**: ~30 minutes to establish team infrastructure  
- **Team Member Onboarding**: ~5 minutes using existing team setup

### 🏆 **What You'll Achieve**
- ✅ Fully configured Apple Developer Account with proper access
- ✅ App Store Connect API keys for secure automation
- ✅ Production-ready team directory structure
- ✅ Complete TestFlight deployment automation
- ✅ Enhanced monitoring with real-time status updates

---

## 🚀 Quick Start (Recommended)

### Step 1: Install via Homebrew (30 seconds)
```bash
brew tap snooky23/tools
brew install apple-deploy
```

### Step 2: Get Apple Credentials (5 minutes)
1. Visit [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
2. Create API key with **App Manager** role
3. Download the `AuthKey_XXXXX.p8` file
4. Note your **Key ID** and **Issuer ID**

### Step 3: Initialize & Deploy (2 minutes)
```bash
# Navigate to your iOS project
cd /path/to/your-ios-app

# Initialize project structure
apple-deploy init

# Add your API key
mv ~/Downloads/AuthKey_XXXXX.p8 apple_info/

# Deploy to TestFlight
apple-deploy deploy \
    team_id="YOUR_TEAM_ID" \
    app_identifier="com.yourcompany.app" \
    apple_id="your@email.com" \
    api_key_id="YOUR_KEY_ID" \
    api_issuer_id="your-issuer-uuid" \
    app_name="Your App" \
    scheme="YourScheme"
```

**🎉 Your app is now live on TestFlight!**

---

## 📋 Detailed Setup Instructions

### 🍎 **Apple Developer Account Setup**

#### 1. Apple Developer Program Membership
- **Individual Account**: $99/year - Perfect for solo developers
- **Organization Account**: $99/year - Required for enterprise teams
- **Enterprise Account**: $299/year - For internal distribution only

#### 2. Create App Store Connect API Key
**Why needed**: Enables secure automation without storing Apple ID passwords

**Steps**:
1. Visit [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **Users and Access** → **Keys** → **App Store Connect API**
3. Click **Generate API Key**
4. Fill in details:
   - **Name**: "iOS Deploy Automation" (or similar)
   - **Access**: **App Manager** (required for TestFlight)
   - **Download**: Save the `AuthKey_XXXXX.p8` file securely
5. **Copy the Key ID and Issuer ID** - you'll need these for deployment

**⚠️ Security Note**: Download the API key immediately - it's only available once!

### 📱 **App Registration**

#### 1. Register Your App Identifier
1. Visit [Apple Developer Portal](https://developer.apple.com/account/)
2. Go to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Click **+** → **App IDs** → **App**
4. Fill in:
   - **Description**: "Your App Name"
   - **Bundle ID**: `com.yourcompany.yourapp` (must match Xcode)
   - **Capabilities**: Enable needed features (Push Notifications, etc.)

#### 2. Create App Store Connect Record
1. Visit [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: Your app name
   - **Primary Language**: English (or preferred)
   - **Bundle ID**: Select from dropdown (registered above)
   - **SKU**: Unique identifier (can be bundle ID)

---

## 🏢 **Team Collaboration Setup**

### **Option 1: Shared Credentials Directory (Recommended)**

**Team Lead Setup** (one-time):
```bash
# Create shared credentials location
mkdir -p /shared/ios-team-credentials
cd /shared/ios-team-credentials

# Initialize structure
apple-deploy init

# Add team credentials
mv ~/Downloads/AuthKey_XXXXX.p8 apple_info/
# Add any existing certificates to apple_info/certificates/

# First deployment creates team certificates
apple-deploy deploy \
    apple_info_dir="/shared/ios-team-credentials/apple_info" \
    team_id="YOUR_TEAM_ID" \
    app_identifier="com.yourteamapp" \
    apple_id="team-lead@company.com" \
    api_key_id="YOUR_KEY_ID" \
    api_issuer_id="your-issuer-uuid" \
    app_name="Team App" \
    scheme="YourScheme"
```

**Team Member Setup** (5 minutes):
```bash
# Install apple-deploy
brew tap snooky23/tools && brew install apple-deploy

# Deploy using shared credentials
cd /path/to/your-ios-app
apple-deploy deploy \
    apple_info_dir="/shared/ios-team-credentials/apple_info" \
    team_id="YOUR_TEAM_ID" \
    app_identifier="com.yourteamapp" \
    apple_id="your@company.com" \
    api_key_id="YOUR_KEY_ID" \
    api_issuer_id="your-issuer-uuid" \
    app_name="Team App" \
    scheme="YourScheme"
```

### **Option 2: Local Project Credentials**

Each developer manages their own project credentials:
```bash
cd /path/to/your-ios-app
apple-deploy init
# Add API key and deploy as in Quick Start
```

---

## 🔧 **Advanced Configuration**

### **Enhanced TestFlight Mode**
```bash
apple-deploy deploy \
    testflight_enhanced="true" \
    # ... other parameters
```
**Features**:
- ⏱️ Upload duration tracking
- 🔄 Real-time processing status
- 📊 Build history display
- 📝 Advanced audit logging
- ✅ Processing confirmation until "Ready to Test"

### **Version Management**
```bash
# Semantic versioning
version_bump="patch"  # 1.0.0 → 1.0.1
version_bump="minor"  # 1.0.0 → 1.1.0  
version_bump="major"  # 1.0.0 → 2.0.0

# App Store integration
version_bump="auto"   # Smart conflict resolution
version_bump="sync"   # Sync with App Store + patch
```

### **Multi-Team Support**
```bash
# Team A
apple-deploy deploy apple_info_dir="/secure/apple_info" team_id="ABC1234567" ...

# Team B  
apple-deploy deploy apple_info_dir="/secure/apple_info" team_id="DEF7890123" ...
```

---

## ✅ **Verification & Testing**

### **Check Setup Status**
```bash
apple-deploy status \
    apple_info_dir="./apple_info" \
    team_id="YOUR_TEAM_ID" \
    app_identifier="com.yourapp"
```

**Expected Output**:
```
📋 Apple Deploy Platform Status Check

✅ API Key: AuthKey_ABCD123456.p8 (valid)
✅ Team ID: ABC1234567 (authenticated)
✅ App ID: com.yourapp (registered)
✅ Certificates: 2 development, 3 distribution (valid)
✅ Profiles: App Store profile found (expires: Dec 2025)
✅ Xcode Project: MyApp.xcodeproj (configured)
✅ Build Scheme: MyApp (found)

🎯 Status: READY FOR DEPLOYMENT
```

### **Certificate Setup Only**
```bash
# Test certificate creation without building
apple-deploy setup_certificates \
    apple_info_dir="./apple_info" \
    team_id="YOUR_TEAM_ID" \
    app_identifier="com.yourapp"
```

---

## 🐛 **Common Setup Issues**

### **"App icon is missing"**
**Solution**: Add proper app icon to Xcode project
1. Open Xcode → `Assets.xcassets` → `AppIcon`
2. Add all required sizes or use [appicon.co](https://appicon.co)
3. Retry deployment

### **"API key file not found"**
**Solution**: Check file location
```bash
# Verify API key location
ls -la apple_info/AuthKey_*.p8

# Move if needed
mv ~/Downloads/AuthKey_*.p8 apple_info/
```

### **"Team ID not found"**
**Solution**: Get your Team ID
1. Visit [Apple Developer Portal](https://developer.apple.com/account/)
2. **Membership Details** → Copy **Team ID** (10 characters)

---

## 📊 **Setup Success Criteria**

### **✅ Solo Developer**
- [ ] Apple Developer Program membership active
- [ ] App Store Connect API key created and downloaded
- [ ] App registered in both Developer Portal and App Store Connect
- [ ] `apple-deploy` installed via Homebrew
- [ ] First TestFlight deployment successful
- [ ] App icon properly configured

### **✅ Team Lead**
- [ ] All solo developer criteria met
- [ ] Shared credentials directory established
- [ ] Team certificates created and exported
- [ ] Team member access documented
- [ ] Multi-team structure if managing multiple teams

### **✅ Team Member**
- [ ] `apple-deploy` installed via Homebrew
- [ ] Access to shared credentials directory
- [ ] First deployment using shared credentials successful
- [ ] Understanding of team workflow

---

## 🚀 **What's Next?**

After successful setup, you can:

1. **Deploy regularly**: `apple-deploy deploy ...`
2. **Version management**: Use semantic versioning with conflict resolution
3. **Team collaboration**: Share credentials or use individual setups
4. **Enhanced monitoring**: Enable TestFlight processing confirmation
5. **Scale operations**: Add more apps and teams as needed

---

## 📞 **Support**

- **Documentation**: [README.md](README.md) for complete reference
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- **Security**: [SECURITY_GUIDE.md](SECURITY_GUIDE.md) for security practices
- **Issues**: [GitHub Issues](https://github.com/snooky23/apple-deploy/issues)

---

*Built for enterprise teams. Production-verified with enhanced Clean Architecture v2.10.0.*
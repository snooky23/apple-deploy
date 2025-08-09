# Product Requirements Document (PRD) - iOS Publishing Automation Platform

## 🎉 **PROJECT STATUS: 100% PRODUCTION READY v1.5** ✅ **SECURE TEMPORARY KEYCHAIN SYSTEM**

### Vision Statement ✅ **FULLY ACHIEVED - COMPLETE AUTOMATION PLATFORM**
Create a comprehensive, automated iOS publishing platform that streamlines the entire TestFlight deployment process with smart version management, eliminating manual configuration errors and reducing deployment time from hours to minutes.

**Achievement**: Complete end-to-end TestFlight automation platform with smart version management, enhanced upload confirmation, and zero-configuration operation.

### Primary Goals ✅ **ALL OBJECTIVES ACHIEVED + SECURITY ENHANCEMENTS**
- ✅ **Smart Version Management**: Automatic TestFlight version checking and intelligent incrementing
- ✅ **Enhanced Upload Confirmation**: 3-method verification with comprehensive status reporting
- ✅ **Temporary Keychain Security**: Isolated certificate management with automatic cleanup
- ✅ **Certificate Infrastructure**: Development & Distribution certificates with secure temporary storage
- ✅ **Apple Developer Portal Integration**: API authentication working with enhanced security
- ✅ **Complete TestFlight Pipeline**: End-to-end automation from build to upload verification
- ✅ **Zero-Config Operation**: Works out-of-the-box with any iOS project structure
- ✅ **Production Quality**: Enterprise-grade error handling, audit logging, and security isolation

### Business Objectives ✅ **ALL OBJECTIVES EXCEEDED + SECURITY ENHANCEMENTS**
- ✅ **TestFlight Automation**: **Complete pipeline** - Build, upload, and verify in one command
- ✅ **Version Management**: **Smart system** - Eliminates duplicate build errors automatically
- ✅ **Upload Confirmation**: **3-method verification** - Comprehensive success confirmation
- ✅ **Certificate Management**: **Secure temporary keychain** - Isolated certificate management with automatic cleanup
- ✅ **Security Isolation**: **Zero system interference** - No permanent changes to developer keychains
- ✅ **Generic App Support**: **Universal compatibility** - Works with any iOS project
- ✅ **Production Readiness**: **100% complete** - Ready for immediate enterprise use with enhanced security

## 2. TARGET AUDIENCE AND USER PERSONAS


### Primary Persona: Development Team Lead ⭐ **CRITICAL COLLABORATION NEED - ENHANCED SECURITY**
- **Profile**: Senior developers managing iOS CI/CD for teams (2-10 developers)
- **Pain Points**: 
  - **Certificate Sharing Complexity**: Manual certificate distribution across team
  - **Cross-Machine Compatibility**: Scripts work on creator's machine but fail on teammate's machine
  - **Team Onboarding Friction**: New developers require extensive manual setup
  - **Deployment Inconsistency**: Different team members have different certificate states
  - **System Keychain Pollution**: Certificate conflicts and permanent changes to developer machines
- **Goals**: 
  - **Seamless Team Collaboration**: Any team member can deploy without manual setup
  - **Standardized Certificate Management**: Shared certificates work across all developer machines
  - **Zero-Configuration Onboarding**: New team members productive in under 5 minutes
  - **Security Isolation**: No permanent changes to individual developer keychains
- **Technical Level**: Advanced iOS and DevOps skills
- **Team Size**: 2-10 developers sharing same iOS project

### Secondary Persona: Solo iOS Developer
- **Profile**: Independent iOS developers or single-person teams
- **Pain Points**: Manual certificate management, complex fastlane setup, deployment errors
- **Goals**: Quick, reliable app publishing with minimal configuration
- **Technical Level**: Intermediate to advanced iOS development skills

### Tertiary Persona: DevOps Engineer
- **Profile**: Engineers setting up iOS CI/CD pipelines for larger organizations
- **Pain Points**: Complex fastlane configurations, certificate management at scale, multi-developer certificate coordination
- **Goals**: Robust, maintainable iOS publishing infrastructure with team collaboration support
- **Technical Level**: Expert in CI/CD and automation tools

## 3. CORE FEATURES AND FUNCTIONALITY

### 3.1 Smart Version Management ✅ **PRODUCTION READY**
- ✅ **TestFlight Version Checking**: Automatic query of latest build numbers on TestFlight
- ✅ **Intelligent Incrementing**: Smart logic to use TestFlight latest + 1 or local + 1
- ✅ **Duplicate Prevention**: Eliminates "build already exists" errors completely
- ✅ **Fallback Logic**: Works even when TestFlight API is unavailable
- ✅ **Audit Trail**: Complete version history logging

### 3.2 Enhanced Upload Confirmation ✅ **PRODUCTION READY**
- ✅ **3-Method Verification System**: 
  - **Method 1**: Spaceship ConnectAPI for full build information retrieval
  - **Method 2**: Basic API connectivity check as fallback
  - **Method 3**: Local build artifact verification (IPA creation check)
- ✅ **Real-time Status**: Processing/Valid/Invalid build states
- ✅ **Detailed Information**: Build numbers, upload times, TestFlight URLs
- ✅ **Comprehensive Logging**: Complete upload history tracking in audit files

### 3.3 Certificate and Provisioning Profile Management ✅ **SECURE TEMPORARY KEYCHAIN SYSTEM**
- ✅ **Temporary Keychain Architecture**: 
  - **Keychain Name**: `fastlane-generic-apple-build.keychain`
  - **Password Strategy**: Uses P12 password for complete integration
  - **Location**: Current working directory for isolation
  - **Lifecycle**: Create → Unlock → Use → Automatic Cleanup
- ✅ **Smart Certificate Detection**: 3-tier intelligent detection system
  - **Option 1**: Create isolated temporary keychain for build process
  - **Option 2**: Import P12 files from `certificates/` directory to temporary keychain
  - **Option 3**: Create new certificates via App Store Connect API when needed
- ✅ **Automated Certificate Creation**: Complete API integration with App Store Connect
- ✅ **Apple Certificate Limit Management**: 
  - Real-time monitoring of certificate limits (2 Development, 3 Distribution)
  - Intelligent cleanup prioritizing API-created certificates
  - Fallback to oldest certificate removal when needed
- ✅ **Provisioning Profile Automation**: 
  - Automatic profile creation and installation
  - Bundle ID auto-creation when missing
  - Profile name detection and code signing integration
- ✅ **P12 Export**: Export certificates to P12 format for CI/CD systems and local storage
- ✅ **Certificate Validation**: Verify certificate validity, expiration, and temporary keychain availability
- ✅ **Security Benefits**: 
  - **Complete Isolation**: Zero interference with system keychain
  - **Automatic Cleanup**: Temporary keychain deleted after each build
  - **Team Consistency**: Identical certificate environment across developers
  - **CI/CD Optimization**: Perfect for automated build environments

### 3.4 Complete TestFlight Pipeline ✅ **PRODUCTION READY**
- ✅ **Automatic Project Detection**: Finds .xcodeproj/.xcworkspace files universally
- ✅ **Dynamic Scheme Detection**: Auto-discovers build schemes with fallback logic
- ✅ **Manual Code Signing**: Production-ready certificate and profile assignment
- ✅ **IPA Generation**: Complete build pipeline with App Store export settings
- ✅ **TestFlight Upload**: Direct upload with retry logic and exponential backoff
- ✅ **Upload Verification**: 3-method confirmation system with detailed status reporting
- **TestFlight Upload**: Automated upload to TestFlight with metadata
- **Build Verification**: Verify IPA integrity and version numbers before upload
- **Multi-Configuration Support**: Support for Debug, Release, and custom build configurations

### 3.3 Multi-Developer Team Collaboration ✅ **CRITICAL ENHANCEMENT**

#### **Team Collaboration Workflow**
- **Shared Certificate Management**: 
  - P12 certificate files with standardized passwords for team sharing
  - Automatic certificate import to each team member's keychain
  - Cross-machine compatibility ensuring certificates work on any developer's machine
- **Team Onboarding Process**:
  ```bash
  # New team member setup (5 minutes)
  1. git clone project-repo
  2. ./scripts/deploy.sh setup_certificates    # Auto-imports team certificates
  3. ./scripts/deploy.sh build_and_upload      # Deploy immediately
  ```
- **Machine-Independent Deployment**: Any team member can deploy to TestFlight without manual configuration
- **Certificate Lifecycle Management**: Automatic certificate validation and refresh across team

#### **Enhanced P12 Certificate Import System**
- **Cross-Machine Keychain Management**: Robust P12 import with retry logic and validation
- **Certificate Validation Pipeline**: Pre-build verification ensuring certificates are accessible
- **Team Certificate Synchronization**: Automatic detection and resolution of certificate state differences
- **Import Failure Recovery**: Intelligent fallback strategies when certificate import fails

### 3.4 Flexible Project Structure and Organization ✅ **ENHANCED - APPLE INFO DIRECTORY PATTERN**

#### **Current Pattern (Production Ready)**
- **Root-Level Separation**: 
  - `main_dir/` - Project root directory (auto-detected from script location)
  - `app_dir/` - Xcode project files and runtime fastlane scripts (default: `main_dir/app`)
  - `certificates_dir/` - Certificate and P12 files (default: `main_dir/certificates`, gitignored)
  - `profiles_dir/` - Provisioning profiles (default: `main_dir/profiles`, gitignored)
  - `scripts_dir/` - Master fastlane and automation scripts (default: `main_dir/scripts`)

#### **Enhanced Apple Info Pattern (Recommended)** 🔄
- **Simplified Directory Structure**:
  ```
  my_app/                    # App directory (any name)
  ├── apple_info/            # Centralized Apple-related files
  │   ├── certificates/      # API keys (.p8), certificates (.cer), P12 files (.p12)
  │   │   ├── AuthKey_XXXXX.p8       # App Store Connect API key
  │   │   ├── development.cer        # Development certificate
  │   │   ├── development.p12        # Development P12 export
  │   │   ├── distribution.cer       # Distribution certificate
  │   │   └── distribution.p12       # Distribution P12 export
  │   ├── profiles/         # Provisioning profiles (.mobileprovision)
  │   │   ├── Development_com.app.mobileprovision
  │   │   └── AppStore_com.app.mobileprovision
  │   └── config.env        # Configuration file
  ├── fastlane/             # Runtime FastLane scripts (copied)
  └── MyApp.xcodeproj/      # Xcode project
  ```
- **Parameter Simplification**: Reduces from 5 directory parameters to 2 core parameters
- **Logical Organization**: Groups all Apple-specific files in dedicated container
- **Self-Contained Apps**: Each app directory contains everything needed
- **Eliminates Duplication**: No more API key copies across directories

#### **Universal Features**
- **Complete Directory Customization**: All directory paths configurable via command-line parameters
- **Auto-Detection**: Script automatically detects project root from its location
- **Path Flexibility**: Supports both relative and absolute paths with automatic conversion
- **Dynamic Script Deployment**: 
  - Copy `scripts_dir/fastlane/` directory to `app_dir/fastlane/` before execution
  - Copy `scripts_dir/fastlane_config.rb` to `app_dir/` if needed
  - Ensure scripts run within the app directory context for proper Xcode project detection
  - Clean up copied scripts after execution (optional)
- **Configuration Management**: Centralized parameter management and validation with directory override support
- **Backward Compatibility**: Both patterns supported for seamless migration

### 3.4 Command-Line Interface
- **Two Primary Commands**:
  1. `fastlane setup_certificates` - Certificate and provisioning profile creation
  2. `fastlane build_and_upload` - Complete build and TestFlight upload
- **Parameter Validation**: Comprehensive validation of all required parameters
- **Progress Reporting**: Clear, emoji-enhanced progress indicators
- **Error Handling**: Detailed error messages with resolution guidance

## 4. TECHNICAL REQUIREMENTS

### 4.1 Dependencies and Tools
- **Ruby**: >= 2.7.0 for fastlane execution
- **Fastlane**: >= 2.200.0 with required plugins
- **Xcode**: >= 12.0 for iOS building
- **macOS**: >= 11.0 for iOS development support
- **App Store Connect API**: P8 key file and API credentials

### 4.2 Required Parameters

| Parameter | Example Value | Description |
|-----------|---------------|-------------|
| `app_identifier` | `com.voiceforms` | Bundle ID |
| `apple_id` | `perchik.omer@gmail.com` | Apple ID email |
| `team_id` | `NA5574MSN5` | Developer Team ID |
| `api_key_path` | `../AuthKey_ZLDUP533YR.p8` | Path to API key file |
| `api_key_id` | `ZLDUP533YR` | API Key ID |
| `api_issuer_id` | `69a6de8f-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | API Issuer ID |
| `app_name` | `"Voice Forms"` | App display name |
| `scheme` | `template_swiftui` | Xcode scheme |
| `configuration` | `Release` | Build configuration |

### 4.3 File Structure Requirements

#### **Current Root-Level Pattern (Supported)**
```
ios-fastlane-auto-deploy/
├── app/                    # Xcode project directory
├── certificates/           # Certificates and P12 files (gitignored)
├── profiles/              # Provisioning profiles (gitignored)
├── scripts/               # Fastlane scripts
│   ├── fastlane/
│   │   └── Fastfile
│   └── fastlane_config.rb
├── .gitignore            # Excludes sensitive files
└── PRD.md               # This document
```

#### **Recommended Apple Info Pattern** 🌟
```
my_ios_app/                 # App directory (any name)
├── apple_info/             # Apple-specific files container
│   ├── certificates/       # API keys (.p8), certificates (.cer), P12 files (.p12) (gitignored)
│   │   ├── AuthKey_XXXXX.p8           # App Store Connect API key
│   │   ├── development.cer            # Development certificate
│   │   ├── development_exported.p12   # Development P12 export (team sharing)
│   │   ├── distribution.cer           # Distribution certificate
│   │   └── distribution_exported.p12  # Distribution P12 export (team sharing)
│   ├── profiles/          # Provisioning profiles (.mobileprovision) (gitignored)
│   │   ├── Development_com.app.mobileprovision
│   │   └── AppStore_com.app.mobileprovision
│   └── config.env         # Configuration file (gitignored)
├── fastlane/              # Runtime FastLane scripts (copied during execution)
│   ├── Fastfile
│   └── README.md
├── MyApp.xcodeproj/       # Xcode project
└── MyApp/                 # Source code
```

#### **Benefits of Apple Info Pattern**
- **Simplified Parameters**: `app_dir="./my_app"` automatically finds apple_info subdirectories
- **Organization**: All Apple-related files grouped logically
- **Self-Contained**: Each app directory contains everything needed
- **Multi-App Friendly**: Support multiple apps without root-level directory conflicts
- **Migration Ready**: Simple `mkdir apple_info && mv certificates profiles config.env apple_info/`

### 4.4 Security Requirements
- **Sensitive Data Protection**: Git ignore certificates and provisioning profiles
- **API Key Security**: Secure handling of App Store Connect API keys
- **Certificate Management**: Proper keychain integration for certificate storage
- **Access Control**: Team-based access controls for shared projects

## 5. USAGE EXAMPLES ✅ **PRODUCTION READY**

### 5.1 Team Collaboration Workflows ✅ **MULTI-DEVELOPER READY**

#### **Team Lead Initial Setup**
```bash
# ✅ ONE-TIME TEAM SETUP: Creates shared certificates for entire team
./scripts/deploy.sh build_and_upload \
  app_identifier="com.voiceforms" \
  apple_id="team-lead@company.com" \
  team_id="NA5574MSN5" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="XXXXX" \
  api_issuer_id="your-issuer-id" \
  app_name="Team App" \
  scheme="YourScheme"

# Result: P12 certificates exported for team sharing
# Commit: certificates/ and profiles/ directories to shared repository
```

#### **Team Member Deployment (Any Developer)**
```bash
# ✅ ZERO-CONFIG DEPLOYMENT: Works on any team member's machine
./scripts/deploy.sh build_and_upload \
  app_identifier="com.voiceforms" \
  apple_id="any-team-member@company.com" \
  team_id="NA5574MSN5" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="XXXXX" \
  api_issuer_id="your-issuer-id" \
  app_name="Team App" \
  scheme="YourScheme"

# Automatic: Imports team certificates to local keychain
# Deploys: Builds and uploads to TestFlight seamlessly
```

### 5.2 Complete End-to-End TestFlight Publishing ✅

**What happens:**
1. 🔍 Smart certificate detection across Keychain, files, and API
2. 📊 Apple certificate limit management with intelligent cleanup  
3. 📋 Provisioning profile creation and installation
4. 🔨 iOS app building with proper code signing
5. ☁️ TestFlight upload with retry logic and verification
6. ✅ Processing status monitoring and success reporting

### 5.3 Certificate Setup Only
```bash
# Solo developer or team lead certificate creation
./scripts/deploy.sh setup_certificates \
  app_identifier="com.voiceforms" \
  apple_id="your@email.com" \
  team_id="NA5574MSN5" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="XXXXX" \
  api_issuer_id="your-issuer-id" \
  app_name="Your App"

# Team member certificate import (from shared P12 files)
./scripts/deploy.sh setup_certificates \
  app_identifier="com.voiceforms" \
  # Automatically imports existing team certificates
```

### 5.4 Team Status and Validation
```bash
# Check team certificate status across machines
./scripts/deploy.sh status \
  app_identifier="com.voiceforms" \
  team_id="NA5574MSN5"

# Validate team member setup
./scripts/deploy.sh validate_team_setup \
  app_identifier="com.voiceforms" \
  team_id="NA5574MSN5"
```

### 5.5 Version Check
```bash
fastlane check_versions \
  app_identifier:com.voiceforms \
  apple_id:perchik.omer@gmail.com \
  team_id:NA5574MSN5 \
  api_key_path:../AuthKey_ZLDUP533YR.p8 \
  api_key_id:ZLDUP533YR \
  api_issuer_id:69a6de8f-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 5.4 Full Pipeline (Setup + Build + Upload)
```bash
fastlane full_pipeline \
  app_identifier:com.voiceforms \
  apple_id:perchik.omer@gmail.com \
  team_id:NA5574MSN5 \
  api_key_path:../AuthKey_ZLDUP533YR.p8 \
  api_key_id:ZLDUP533YR \
  api_issuer_id:69a6de8f-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  app_name:"Voice Forms" \
  scheme:template_swiftui \
  configuration:Release
```

### 5.5 Optional Parameters
```bash
# Add these to any command above if needed:
skip_waiting:true                    # Don't wait for build processing
changelog:"Your release notes here"  # Custom changelog
skip_build_increment:true           # Skip version bumping
password:"custom_p12_password"      # Custom P12 password
```

## 6. SUCCESS METRICS

### 6.1 Performance Metrics
- **Deployment Time**: Target 15-30 minutes for complete deployment (vs 2-4 hours manual)
- **Success Rate**: >95% successful deployments without manual intervention
- **Error Reduction**: <5% error rate in certificate/provisioning profile creation
- **Build Consistency**: 100% consistent build configurations across environments

### 6.2 User Experience Metrics
- **Solo Setup Time**: <10 minutes for first-time project setup
- **Team Onboarding Time**: <5 minutes for new team members
- **Learning Curve**: New users productive within 1 hour, team members within 15 minutes
- **Command Complexity**: Maximum 2 commands needed for any workflow
- **Team Collaboration Success**: >95% success rate for cross-machine deployments
- **Documentation Clarity**: <5 support requests per 100 users

### 6.3 Business Metrics
- **Solo Developer Productivity**: 80% reduction in deployment-related time
- **Team Productivity**: 90% reduction in team coordination overhead for deployments
- **Error Cost Reduction**: 95% reduction in deployment rollbacks due to certificate/configuration errors
- **Team Adoption Rate**: Target adoption by 50+ development teams within 6 months
- **Cross-Machine Success Rate**: >95% successful deployments on secondary developer machines
- **Maintenance Overhead**: <2 hours/month maintenance per project, <1 hour/month per team member

## 7. TIMELINE AND MILESTONES

### Phase 1: Foundation (Weeks 1-2) ✅ COMPLETED
- ✅ Core fastlane configuration
- ✅ Certificate and provisioning profile automation
- ✅ Basic project structure
- ✅ Git repository setup with security measures

### Phase 2: Build Pipeline (Weeks 3-4)
- **Week 3**: Enhanced build automation and version management
- **Week 4**: TestFlight upload integration and error handling
- **Deliverable**: Complete build_and_upload workflow

### Phase 3: User Experience (Weeks 5-6)
- **Week 5**: Command-line interface improvements and validation
- **Week 6**: Comprehensive error messages and progress reporting
- **Deliverable**: Production-ready CLI with full error handling

### Phase 4: Documentation and Testing (Weeks 7-8)
- **Week 7**: Complete documentation (README, setup guides, troubleshooting)
- **Week 8**: Integration testing and edge case handling
- **Deliverable**: Fully documented, tested solution

### Phase 5: Advanced Features (Weeks 9-10)
- **Week 9**: Multi-environment support and advanced configurations
- **Week 10**: CI/CD integration examples and team workflow optimization
- **Deliverable**: Enterprise-ready publishing platform

### Phase 6: Launch and Support (Weeks 11-12)
- **Week 11**: Beta testing with target users and feedback integration
- **Week 12**: Public release and initial user support
- **Deliverable**: Public availability and user onboarding materials

## 8. WORKFLOW PROCESSES

### 8.1 What the Certificate & Build Process Does
1. ✅ Validates all parameters and files
2. 📂 **Script Deployment**:
   - Copies `scripts/fastlane/` directory to `app/fastlane/` 
   - Copies `scripts/fastlane_config.rb` to `app/` if needed
   - Ensures fastlane runs within app directory context
3. 🔍 **Smart Certificate Detection**:
   - Checks macOS Keychain for existing certificates
   - Scans `certificates/` directory for certificate + P12 files
   - Determines if new certificate creation is needed
4. 🔐 **Certificate Management**:
   - Uses existing certificates if available and valid
   - Creates new certificates via App Store Connect API if needed
   - Manages Apple certificate limits (removes API-created or oldest certificates)
   - Exports certificates to P12 format for future use
5. 📋 Creates/updates provisioning profiles linked to available certificates
6. 🔧 Configures Xcode project settings with proper code signing
7. 📈 Checks App Store & TestFlight for existing versions
8. 🎯 Bumps build number higher than any existing version
9. 🧹 Cleans build directory
10. 🔨 Builds your app with proper code signing
11. 🔍 Verifies IPA has correct version
12. ☁️ Uploads to TestFlight
13. 🧼 Cleanup copied fastlane scripts (optional)
14. 🎉 Shows success summary

### 8.2 Post-Upload Actions
After upload, developers should:
- Go to App Store Connect → TestFlight to manage the build
- Add external testers if needed
- Submit for App Store review when ready

## 9. RISK ASSESSMENT AND MITIGATION

### High-Risk Items
- **Apple API Changes**: Regular monitoring of App Store Connect API updates
- **Certificate Expiration**: Automated expiration monitoring and renewal alerts
- **Xcode Compatibility**: Testing across multiple Xcode versions

### Medium-Risk Items
- **Complex Project Structures**: Support for workspaces and multiple targets
- **Team Coordination**: Clear documentation for shared project usage
- **Error Recovery**: Robust rollback mechanisms for failed deployments

### Mitigation Strategies
- Comprehensive testing across different project configurations
- Regular updates to maintain compatibility with Apple's ecosystem
- Clear documentation and troubleshooting guides
- Active monitoring of user feedback and issues

## 10. GETTING STARTED

### Prerequisites
1. macOS with Xcode installed
2. Ruby 2.7+ with fastlane installed
3. Apple Developer Account with App Store Connect API access
4. P8 API key file from App Store Connect

### Quick Setup

#### **Team Collaboration (Multi-Developer)** 🌟 **RECOMMENDED**

**Team Lead (One-time setup):**
1. Initialize project with certificates: `./scripts/deploy.sh setup_certificates`
2. Commit certificates to shared repository: `git add certificates/ profiles/`
3. Share repository with team members

**Team Members (5-minute setup):**
1. Clone shared repository: `git clone team-project`
2. Import team certificates: `./scripts/deploy.sh setup_certificates`
3. Deploy immediately: `./scripts/deploy.sh build_and_upload`

**Daily Workflow:**
- Any team member can deploy with: `./scripts/deploy.sh build_and_upload`
- No manual certificate management required
- Automatic cross-machine compatibility

#### **Team Collaboration Setup (Recommended)** 🌟
1. **Team Lead Setup**:
   ```bash
   git clone team-ios-project && cd team-ios-project
   ./scripts/deploy.sh setup_certificates app_identifier="com.teamapp"
   git add certificates/ profiles/ && git commit -m "Add team certificates"
   git push  # Share certificates with team
   ```

2. **Team Member Setup**:
   ```bash
   git clone team-ios-project && cd team-ios-project
   ./scripts/deploy.sh setup_certificates  # Auto-imports team certificates
   ./scripts/deploy.sh build_and_upload     # Deploy immediately
   ```

#### **Apple Info Pattern (Solo Developer)**

#### **Root-Level Pattern (Legacy)**
1. Clone this repository
2. Place your P8 API key in the `certificates/` directory
3. Update the command with your app's parameters
4. Run `./scripts/deploy.sh build_and_upload` with your parameters (RECOMMENDED)
   - OR run `cd app && fastlane build_and_upload` (requires manual script copying)

### Getting Your API Issuer ID
1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
2. Find your API key (e.g., ZLDUP533YR)
3. Copy the Issuer ID (format: 69a6de8f-xxxx-xxxx-xxxx-xxxxxxxxxxxx)

---

This PRD provides a comprehensive framework for creating a robust, user-friendly iOS publishing automation platform that addresses the specific needs outlined while ensuring scalability and maintainability.
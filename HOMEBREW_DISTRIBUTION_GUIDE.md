# 📦 Homebrew Distribution Guide
## iOS FastLane Auto Deploy Platform

This guide provides comprehensive instructions for distributing the iOS FastLane Auto Deploy platform via Homebrew, including packaging strategies, security considerations, and submission processes.

---

## 🎯 Overview

The iOS FastLane Auto Deploy platform is a complex shell script and Ruby-based tool that requires careful packaging for Homebrew distribution. This guide covers the complete distribution strategy from formula creation to user installation.

### Key Distribution Challenges
- **Multi-language codebase**: Shell scripts + Ruby + FastLane integration
- **Security-sensitive**: Handles Apple certificates and API keys
- **macOS-only**: iOS development requires macOS and Xcode tools
- **Complex dependencies**: Ruby gems, FastLane, Xcode Command Line Tools

---

## 📋 Package Analysis

### Current Project Structure
```
ios-fastlane-auto-deploy/
├── scripts/deploy.sh              # Main entry point (shell script)
├── scripts/fastlane/Fastfile      # FastLane automation logic (Ruby)
├── scripts/domain/                # Clean architecture (Ruby)
├── Gemfile                       # Ruby dependencies
└── apple_info/                   # User configuration directory
```

### Dependencies Identified
- **System**: macOS, Xcode Command Line Tools
- **Language Runtime**: Ruby 3.2+
- **Core**: FastLane CLI tool
- **Ruby Gems**: fastlane, multipart-post, xcode-install, cocoapods
- **Optional**: Various iOS development tools

---

## 🏗️ Packaging Strategy

### 1. Installation Method: **Source-based with Wrapper CLI**

**Rationale**: The tool consists of shell scripts and Ruby files that need to maintain their structure and file permissions. A source-based installation with a CLI wrapper provides the best balance of functionality and user experience.

### 2. Formula Structure
- **Install Location**: `/opt/homebrew/libexec/ios-fastlane-auto-deploy/`
- **CLI Wrapper**: `/opt/homebrew/bin/apple-deploy`
- **Configuration**: `/opt/homebrew/etc/apple-deploy/`
- **Logs**: `/opt/homebrew/var/log/apple-deploy/`

### 3. Dependency Management
```ruby
depends_on "ruby@3.2"           # Specific Ruby version for stability
depends_on "fastlane"           # Core FastLane tool
depends_on :macos               # macOS-only requirement
```

---

## 📄 Complete Homebrew Formula

The formula has been created as `ios-fastlane-auto-deploy.rb` with the following key features:

### Key Formula Components

#### 1. **Metadata & Dependencies**
```ruby
desc "Enterprise-grade iOS TestFlight automation platform"
homepage "https://github.com/snooky23/ios-fastlane-auto-deploy"
license "MIT"
depends_on "ruby@3.2"
depends_on "fastlane"
depends_on :macos
```

#### 2. **Installation Process**
- Installs entire codebase to `libexec` to avoid conflicts
- Creates CLI wrapper script at `bin/apple-deploy`
- Sets up Ruby gem environment with bundler
- Creates configuration and logging directories
- Installs man page documentation

#### 3. **CLI Wrapper Features**
- **Project Validation**: Ensures commands run in valid iOS project directories
- **Command Routing**: Routes commands to original `deploy.sh` with proper environment
- **User-Friendly Interface**: Provides help, version, and init commands
- **Error Handling**: Clear error messages and usage guidance

#### 4. **Configuration Management**
- Global configuration template at `/opt/homebrew/etc/apple-deploy/config.example`
- Project-specific configuration in `./apple_info/config.env`
- Automatic structure initialization with `apple-deploy init`

---

## 🚀 Step-by-Step Homebrew Submission Process

### Phase 1: Preparation (Complete)

#### 1.1 ✅ Repository Preparation
- [x] Clean git repository structure
- [x] Proper LICENSE file (MIT)
- [x] Comprehensive README.md
- [x] Tagged releases with semantic versioning

#### 1.2 ✅ Formula Creation
- [x] Complete Homebrew formula (`ios-fastlane-auto-deploy.rb`)
- [x] CLI wrapper with full functionality
- [x] Man page documentation
- [x] Test suite integration

### Phase 2: Testing & Validation

#### 2.1 Local Formula Testing
```bash
# Test formula installation locally
brew install --build-from-source ./ios-fastlane-auto-deploy.rb

# Test CLI functionality
apple-deploy version
apple-deploy help

# Test in sample iOS project
cd /path/to/ios/project
apple-deploy init
apple-deploy status

# Test formula uninstallation
brew uninstall ios-fastlane-auto-deploy
```

#### 2.2 Formula Validation
```bash
# Validate formula syntax
brew audit --strict --online ios-fastlane-auto-deploy.rb

# Check formula style
brew style ios-fastlane-auto-deploy.rb

# Test formula installation from URL
brew install https://raw.githubusercontent.com/snooky23/ios-fastlane-auto-deploy/main/ios-fastlane-auto-deploy.rb
```

### Phase 3: Release Preparation

#### 3.1 Create GitHub Release
```bash
# Tag the release
git tag -a v2.3.0 -m "Release v2.3.0: Homebrew distribution ready"
git push origin v2.3.0

# Create GitHub release with assets
gh release create v2.3.0 \
  --title "v2.3.0: Homebrew Distribution" \
  --notes "Complete Homebrew formula with CLI wrapper and documentation" \
  ios-fastlane-auto-deploy.rb
```

#### 3.2 Calculate Release SHA256
```bash
# Download release tarball and calculate SHA256
curl -L https://github.com/snooky23/ios-fastlane-auto-deploy/archive/refs/tags/v2.3.0.tar.gz -o release.tar.gz
shasum -a 256 release.tar.gz

# Update formula with actual SHA256
# Replace PLACEHOLDER_SHA256 in ios-fastlane-auto-deploy.rb
```

### Phase 4: Homebrew Submission

#### 4.1 Tap Strategy Options

**Option A: Official Homebrew Core (Recommended for wide adoption)**
```bash
# Fork homebrew-core repository
gh repo fork Homebrew/homebrew-core

# Add formula to appropriate directory
cp ios-fastlane-auto-deploy.rb homebrew-core/Formula/i/ios-fastlane-auto-deploy.rb

# Create pull request
cd homebrew-core
git checkout -b ios-fastlane-auto-deploy
git add Formula/i/ios-fastlane-auto-deploy.rb
git commit -m "Add ios-fastlane-auto-deploy formula"
git push origin ios-fastlane-auto-deploy
gh pr create --title "Add ios-fastlane-auto-deploy formula" \
  --body "Enterprise-grade iOS TestFlight automation platform"
```

**Option B: Custom Tap (Faster, more control)**
```bash
# Create homebrew-tap repository
gh repo create snooky23/homebrew-ios-tools --public

# Add formula to tap
git clone https://github.com/snooky23/homebrew-ios-tools.git
cd homebrew-ios-tools
mkdir -p Formula
cp ../ios-fastlane-auto-deploy.rb Formula/
git add Formula/ios-fastlane-auto-deploy.rb
git commit -m "Add ios-fastlane-auto-deploy formula"
git push origin main
```

#### 4.2 Documentation Update
```bash
# Update README with Homebrew installation instructions
echo "
## 📦 Homebrew Installation

### Install via Official Tap (when approved)
\`\`\`bash
brew install ios-fastlane-auto-deploy
\`\`\`

### Install via Custom Tap (immediate availability)
\`\`\`bash
brew tap snooky23/ios-tools
brew install ios-fastlane-auto-deploy
\`\`\`

### Quick Start
\`\`\`bash
cd /path/to/your/ios/project
apple-deploy init
apple-deploy deploy team_id=\"YOUR_TEAM_ID\" app_identifier=\"com.your.app\" [...]
\`\`\`
" >> README.md
```

---

## 🔧 CLI Wrapper Design

### Command Interface
```bash
# Primary Commands
apple-deploy deploy                  # Main deployment command
apple-deploy build_and_upload        # Alias for deploy
apple-deploy setup_certificates      # Certificate setup
apple-deploy init                    # Project initialization
apple-deploy status                  # Configuration status
apple-deploy help                    # Usage information
apple-deploy version                 # Version information
```

### Parameter Handling
```bash
# All original parameters supported
apple-deploy deploy \
  team_id="YOUR_TEAM_ID" \
  app_identifier="com.myapp" \
  apple_id="dev@email.com" \
  api_key_path="AuthKey_ABC123.p8" \
  api_key_id="ABC123" \
  api_issuer_id="12345678-1234-1234-1234-123456789012" \
  app_name="My App" \
  scheme="MyApp" \
  testflight_enhanced="true"
```

### Environment Setup
- **Ruby Environment**: Automatic GEM_HOME and BUNDLE_PATH configuration
- **Path Management**: Proper PATH setup for installed gems
- **Project Detection**: Validates iOS project structure before execution
- **Error Handling**: Clear error messages and usage guidance

---

## 🔒 Security Considerations

### 1. Certificate and API Key Handling
- **No Storage**: Formula never stores or processes sensitive data
- **User Control**: All certificates and API keys remain in user's project directory
- **Temporary Usage**: Sensitive data used only during deployment execution
- **Clean Cleanup**: Automatic cleanup of temporary files and keychains

### 2. Ruby Gem Security
- **Locked Versions**: Gemfile.lock ensures reproducible gem versions
- **Isolated Installation**: Gems installed to formula-specific directory
- **No System Pollution**: No changes to system Ruby environment
- **Dependency Auditing**: Regular security updates for gem dependencies

### 3. File Permissions
- **Restricted Access**: Configuration and log directories with appropriate permissions
- **No Privileged Operations**: No sudo or elevated permissions required
- **User Data Protection**: Sensitive files remain in user-controlled directories

### 4. Network Security
- **HTTPS Only**: All Apple API communication uses HTTPS
- **API Key Validation**: Proper API key format validation
- **Certificate Verification**: SSL certificate verification for all connections

---

## 📚 Installation and Usage Documentation

### For End Users

#### Installation
```bash
# Install via Homebrew (when available in core)
brew install ios-fastlane-auto-deploy

# Or install via custom tap
brew tap snooky23/ios-tools
brew install ios-fastlane-auto-deploy
```

#### Quick Start
```bash
# 1. Navigate to iOS project
cd /path/to/your/ios/project

# 2. Initialize structure
apple-deploy init

# 3. Add credentials to apple_info/
#    - Copy AuthKey_*.p8 to apple_info/
#    - Copy certificates to apple_info/certificates/
#    - Edit apple_info/config.env

# 4. Deploy to TestFlight
apple-deploy deploy \
  team_id="YOUR_TEAM_ID" \
  app_identifier="com.your.app" \
  apple_id="dev@email.com" \
  api_key_path="AuthKey_ABC123.p8" \
  api_key_id="ABC123" \
  api_issuer_id="12345678-1234-1234-1234-123456789012" \
  app_name="Your App" \
  scheme="YourScheme"
```

#### Configuration Options
```bash
# Use configuration file (recommended for teams)
# Edit apple_info/config.env with your settings
apple-deploy deploy  # Uses config.env values

# Override with command-line parameters
apple-deploy deploy team_id="DIFFERENT_TEAM" version_bump="major"

# Enhanced TestFlight monitoring
apple-deploy deploy testflight_enhanced="true"
```

### For Developers

#### Local Development
```bash
# Clone and test locally
git clone https://github.com/snooky23/ios-fastlane-auto-deploy.git
cd ios-fastlane-auto-deploy

# Install locally for testing
brew install --build-from-source ./ios-fastlane-auto-deploy.rb

# Test functionality
apple-deploy version
apple-deploy help
```

#### Contributing
```bash
# Fork and create feature branch
gh repo fork snooky23/ios-fastlane-auto-deploy
git checkout -b feature/new-feature

# Make changes and test
brew uninstall ios-fastlane-auto-deploy
brew install --build-from-source ./ios-fastlane-auto-deploy.rb

# Submit pull request
git commit -m "feat: add new feature"
git push origin feature/new-feature
gh pr create
```

---

## 🧪 Testing Strategy

### Formula Testing
```bash
# Syntax validation
brew audit --strict --online ios-fastlane-auto-deploy.rb
brew style ios-fastlane-auto-deploy.rb

# Installation testing
brew install --build-from-source ./ios-fastlane-auto-deploy.rb
brew test ios-fastlane-auto-deploy

# Functionality testing
apple-deploy version
apple-deploy help
apple-deploy init

# Cleanup testing
brew uninstall ios-fastlane-auto-deploy
# Verify no leftover files
```

### Integration Testing
```bash
# Create test iOS project
mkdir test-ios-app && cd test-ios-app
# Add minimal Xcode project structure

# Test initialization
apple-deploy init

# Test configuration
apple-deploy status

# Test deployment (with mock credentials)
apple-deploy deploy team_id="TEST_TEAM_ID" app_identifier="com.test.app" \
  apple_id="test@example.com" api_key_path="test_key.p8" \
  api_key_id="TEST_KEY" api_issuer_id="test-uuid" \
  app_name="Test App" scheme="TestScheme"
```

### Platform Testing
```bash
# Test on different macOS versions
# - macOS Monterey (12.x)
# - macOS Ventura (13.x)
# - macOS Sonoma (14.x)
# - macOS Sequoia (15.x)

# Test with different Xcode versions
# - Xcode 14.x
# - Xcode 15.x
# - Xcode 16.x (beta)

# Test with different Ruby versions
# - Ruby 3.1
# - Ruby 3.2 (recommended)
# - Ruby 3.3
```

---

## 🎯 Submission Checklist

### Pre-Submission
- [ ] Formula syntax validated with `brew audit`
- [ ] Local installation tested successfully
- [ ] CLI functionality verified
- [ ] Man page renders correctly
- [ ] Documentation updated
- [ ] GitHub release created with proper versioning
- [ ] SHA256 calculated and updated in formula

### Submission Options
- [ ] **Option A**: Submit to Homebrew Core (wider reach)
- [ ] **Option B**: Create custom tap (faster deployment)

### Post-Submission
- [ ] Monitor for community feedback
- [ ] Address any Homebrew maintainer requests
- [ ] Update documentation with installation instructions
- [ ] Announce availability to iOS developer community

---

## 🔗 Additional Resources

### Homebrew Documentation
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae)
- [Homebrew Formula Style Guide](https://docs.brew.sh/Formula-Cookbook#style-guide)

### Project Resources
- **GitHub Repository**: https://github.com/snooky23/ios-fastlane-auto-deploy
- **Issues & Support**: https://github.com/snooky23/ios-fastlane-auto-deploy/issues
- **Documentation**: Project README.md and CLAUDE.md files

### iOS Development Tools
- [FastLane Documentation](https://docs.fastlane.tools/)
- [Xcode Command Line Tools](https://developer.apple.com/xcode/)
- [App Store Connect API](https://developer.apple.com/app-store-connect/api/)

---

## 📊 Expected Outcomes

### User Benefits
- **Simple Installation**: Single `brew install` command
- **System Integration**: Proper CLI tool with man page
- **Project Management**: `apple-deploy init` for easy project setup
- **Familiar Interface**: Consistent with other Homebrew tools

### Developer Benefits
- **Wide Distribution**: Access to Homebrew's large user base
- **Automatic Updates**: Users get updates via `brew upgrade`
- **Professional Packaging**: Industry-standard distribution method
- **Community Feedback**: Homebrew community engagement

### Platform Benefits
- **Increased Adoption**: Easier installation drives usage
- **Enterprise Acceptance**: Professional packaging builds trust
- **Community Growth**: Homebrew visibility attracts contributors
- **Ecosystem Integration**: Plays well with other development tools

---

*This guide provides a complete strategy for distributing the iOS FastLane Auto Deploy platform via Homebrew, ensuring wide accessibility while maintaining security and functionality.*
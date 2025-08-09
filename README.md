# 🚀 iOS Deploy Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Homebrew](https://img.shields.io/badge/Homebrew-Available-green.svg)](https://brew.sh/)
[![macOS](https://img.shields.io/badge/macOS-Required-blue.svg)](https://www.apple.com/macos/)
[![iOS](https://img.shields.io/badge/iOS-Development-orange.svg)](https://developer.apple.com/ios/)

**Enterprise-grade iOS TestFlight automation platform with intelligent certificate management and multi-developer team collaboration.**

## ✨ Key Features

- 🎯 **Complete TestFlight Pipeline** - End-to-end automation from build to upload
- 🔐 **Smart Certificate Management** - Automatic certificate and provisioning profile handling
- 👥 **Multi-Team Collaboration** - Support for multiple developer teams and environments
- 🔄 **Intelligent Version Management** - Automatic version conflict resolution
- 🛡️ **Security-First Design** - Temporary keychain system with automatic cleanup
- 📊 **Enhanced TestFlight Monitoring** - Real-time build processing status
- 🏗️ **Clean Architecture** - Modular, testable, and maintainable codebase

## 📦 Installation

### Homebrew (Recommended)

```bash
brew install ios-deploy-platform
```

### Manual Installation

```bash
git clone https://github.com/avilevin/ios-deploy-platform.git
cd ios-deploy-platform
```

## 🚀 Quick Start

### 1. Initialize Your Project

```bash
cd /path/to/your/ios/project
ios-deploy init
```

### 2. Add Your Credentials

Add your Apple Developer credentials to the `apple_info/` directory:

```bash
apple_info/
├── AuthKey_XXXXX.p8          # App Store Connect API key
├── certificates/
│   └── cert.p12              # Development/Distribution certificates
└── config.env               # Configuration file
```

### 3. Configure Your Settings

Edit `apple_info/config.env`:

```bash
# Apple Developer Team Configuration
TEAM_ID="YOUR_TEAM_ID"
APPLE_ID="your-developer@email.com"

# App Store Connect API
API_KEY_ID="YOUR_API_KEY_ID"
API_ISSUER_ID="12345678-1234-1234-1234-123456789012"
API_KEY_PATH="AuthKey_XXXXX.p8"

# Application Configuration
APP_IDENTIFIER="com.yourcompany.yourapp"
APP_NAME="Your App Name"
SCHEME="YourAppScheme"
```

### 4. Deploy to TestFlight

```bash
ios-deploy deploy \
  team_id="YOUR_TEAM_ID" \
  app_identifier="com.yourcompany.yourapp" \
  apple_id="your@email.com" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="YOUR_KEY_ID" \
  api_issuer_id="your-issuer-uuid" \
  app_name="Your App" \
  scheme="YourScheme"
```

## 📋 Core Commands

| Command | Description |
|---------|-------------|
| `ios-deploy deploy` | Complete build and TestFlight upload |
| `ios-deploy setup_certificates` | Set up certificates and profiles |
| `ios-deploy status` | Show current configuration status |
| `ios-deploy init` | Initialize project structure |
| `ios-deploy help` | Show usage information |
| `ios-deploy version` | Show version information |

## 🎛️ Advanced Configuration

### Version Management

```bash
# Automatic version increment
ios-deploy deploy version_bump="patch"    # 1.0.0 → 1.0.1
ios-deploy deploy version_bump="minor"    # 1.0.0 → 1.1.0
ios-deploy deploy version_bump="major"    # 1.0.0 → 2.0.0

# Smart App Store integration
ios-deploy deploy version_bump="auto"     # Automatic conflict resolution
ios-deploy deploy version_bump="sync"     # Sync with App Store + patch
```

### Enhanced TestFlight Mode

```bash
# Extended confirmation with real-time processing monitoring
ios-deploy deploy testflight_enhanced="true" [other_parameters...]

# Standalone TestFlight status check
ios-deploy check_testflight_status_standalone [parameters...]
```

### Multi-Team Setup

```bash
# Use custom apple_info directory for team isolation
ios-deploy deploy \
  apple_info_dir="/shared/ios-teams/TEAM_A" \
  team_id="TEAM_A_ID" \
  [other_parameters...]
```

## 🏗️ Architecture

The iOS Deploy Platform is built with clean architecture principles:

- **Domain Layer**: Business logic for certificates, profiles, and applications
- **Infrastructure Layer**: Apple API integration and external services
- **Use Cases**: Modular automation workflows
- **Repository Pattern**: Abstracted data access layer
- **Dependency Injection**: Testable and maintainable code structure

## 🔒 Security Features

- **Zero Credential Storage** - No sensitive data stored by the platform
- **Temporary Keychain System** - Isolated certificate operations
- **Automatic Cleanup** - No permanent system changes
- **Input Validation** - Comprehensive parameter sanitization
- **Secure Communication** - HTTPS-only Apple API communication

## 📊 Real-World Usage

Successfully used in production for:
- **Enterprise iOS teams** with 5+ developers
- **CI/CD pipelines** with automated deployments
- **Multi-app portfolios** with shared infrastructure
- **TestFlight automation** with 100+ builds per month

### Example Production Command

```bash
ios-deploy deploy \
  version_bump="patch" \
  app_identifier="com.voiceforms" \
  apple_id="dev@company.com" \
  team_id="NA5574MSN5" \
  apple_info_dir="/shared/apple-credentials" \
  api_key_id="ZLDUP533YR" \
  api_issuer_id="63cb40ec-3fb4-4e64-b8f9-1b10996adce6" \
  app_name="Voice Forms" \
  scheme="ProductionApp" \
  configuration="Release" \
  testflight_enhanced="true"
```

## 🛠️ Requirements

- **macOS** with Xcode Command Line Tools
- **Ruby 3.2+** (automatically managed by Homebrew)
- **FastLane** (automatically installed)
- **Valid Apple Developer Account**
- **App Store Connect API Key**

## 🔧 Troubleshooting

### Common Issues

**Certificate Problems:**
```bash
ios-deploy setup_certificates [parameters...]
security find-identity -v -p codesigning
```

**Version Conflicts:**
```bash
ios-deploy deploy version_bump="auto" [parameters...]
```

**TestFlight Upload Issues:**
- Verify API key permissions in App Store Connect
- Check network connectivity and firewall settings
- Use `ios-deploy status` to validate configuration

## 🤝 Contributing

We welcome contributions! Please see our:
- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [FastLane](https://fastlane.tools/) for iOS automation
- Inspired by enterprise iOS development workflows
- Community-driven improvements and feedback

---

## 📈 Status: Production Ready v2.3.0

✅ **Complete TestFlight Publishing Pipeline**  
✅ **Enhanced TestFlight Confirmation & Logging**  
✅ **Smart Provisioning Profile Management**  
✅ **Multi-Team Directory Structure**  
✅ **Advanced Version Management**  
✅ **100% Production Stability**  

**Built for enterprise teams. Distributed via [Homebrew](https://brew.sh/). Enhanced with [Claude Code](https://claude.ai/code).**

---

For detailed documentation and advanced usage, see:
- [CLAUDE.md](CLAUDE.md) - Complete platform documentation
- [SECURITY_GUIDE.md](SECURITY_GUIDE.md) - Security best practices
- [HOMEBREW_DISTRIBUTION_GUIDE.md](HOMEBREW_DISTRIBUTION_GUIDE.md) - Distribution details
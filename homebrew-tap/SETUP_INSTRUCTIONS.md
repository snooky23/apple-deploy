# Homebrew Tap Setup Instructions

## Step 1: Create GitHub Repository

Create a new repository called `homebrew-ios-tools`:

```bash
# Via GitHub CLI
gh repo create snooky23/homebrew-ios-tools --public

# Or visit: https://github.com/new
# Repository name: homebrew-ios-tools
# Make it public
```

## Step 2: Push Tap Formula

```bash
# Clone the new repository
git clone https://github.com/snooky23/homebrew-ios-tools.git
cd homebrew-ios-tools

# Copy the formula
cp ../apple-deploy/homebrew-tap/apple-deploy.rb ./Formula/apple-deploy.rb
cp ../apple-deploy/homebrew-tap/README.md ./README.md

# Commit and push
git add .
git commit -m "Add apple-deploy formula v2.3.0"
git push origin main
```

## Step 3: Test Installation

```bash
# Add the tap locally
brew tap snooky23/ios-tools

# Install the platform
brew install apple-deploy

# Test the installation
apple-deploy version
apple-deploy help
```

## Step 4: Update Documentation

Update the main project README with:

```markdown
## 📦 Homebrew Installation

```bash
# Add the tap
brew tap snooky23/ios-tools

# Install the platform
brew install apple-deploy

# Quick project setup
cd /path/to/your-ios-app
apple-deploy init
```

## Directory Structure Required

The Homebrew tap repository should look like:

```
homebrew-ios-tools/
├── Formula/
│   └── apple-deploy.rb    # The Homebrew formula
└── README.md                     # Tap documentation
```

## Manual Testing Commands

```bash
# Test formula syntax
brew audit --strict apple-deploy

# Test installation from local file
brew install --build-from-source ./Formula/apple-deploy.rb

# Test all functionality
apple-deploy version
apple-deploy help
cd /path/to/test/ios/project
apple-deploy init
```

## Notes

- The tap name must follow the pattern `homebrew-NAME`
- Formula files go in the `Formula/` directory
- The formula class name should match the filename
- SHA256 must match the actual release tarball
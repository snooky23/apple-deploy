#!/bin/bash

# iOS Publishing Automation Platform - Deploy Script
# This script performs complete end-to-end TestFlight deployment

set -e  # Exit on any error

# Set environment variables for non-interactive mode
export FASTLANE_DISABLE_COLORS=1
export CI=true

# Enhanced logging configuration with progress tracking
DEBUG_MODE=${DEBUG_MODE:-false}
VERBOSE_MODE=${VERBOSE_MODE:-false}
# Create build/logs directory for organized log storage
BUILD_LOGS_DIR="${PWD}/build/logs"
mkdir -p "$BUILD_LOGS_DIR" 2>/dev/null || BUILD_LOGS_DIR="${PWD}"
LOG_FILE="${BUILD_LOGS_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"

# Progress tracking variables
TOTAL_STEPS=6
CURRENT_STEP=0
DEPLOYMENT_START_TIME=$(date +%s)

# Progress indicators with emojis
PROGRESS_EMOJIS=("🟦" "🟨" "🟧" "🟩" "🟪" "🟫")
STATUS_EMOJIS=("⏳" "🔄" "✅" "❌" "⚠️" "📋")

# Enhanced logging functions with progress indicators
log_debug() {
    show_status "debug" "$1"
}

log_info() {
    show_status "info" "$1"
}

log_success() {
    show_status "success" "$1"
}

log_warning() {
    show_status "warning" "$1"
}

log_error() {
    show_status "error" "$1"
}

# Unified formatting functions for consistent output alignment
show_header() {
    local title="$1"
    local icon="${2:-🔍}"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║ ${icon} ${title}"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_section() {
    local title="$1"
    local icon="${2:-📋}"
    echo ""
    echo "${icon} ${title}..."
    echo ""
}

show_status() {
    local status="$1"
    local message="$2"
    local timestamp="$(date '+%H:%M:%S')"
    case "$status" in
        "success")
            echo "✅ [SUCCESS $timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        "info")
            echo "ℹ️  [INFO $timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        "warning")
            echo "⚠️  [WARNING $timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        "error")
            echo "❌ [ERROR $timestamp] $message" | tee -a "$LOG_FILE"
            ;;
        "debug")
            if [ "$DEBUG_MODE" = "true" ]; then
                echo "🔍 [DEBUG $timestamp] $message" | tee -a "$LOG_FILE"
            fi
            ;;
        *)
            echo "$message" | tee -a "$LOG_FILE"
            ;;
    esac
}

show_separator() {
    local char="${1:-━}"
    echo ""
    echo "${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}${char}"
    echo ""
}

show_result_summary() {
    local success="$1"
    local message="$2"
    local details="$3"
    
    show_separator
    if [ "$success" = "true" ]; then
        echo "✅ $message"
    else
        echo "❌ $message"
    fi
    
    if [ -n "$details" ]; then
        echo ""
        echo "$details"
    fi
    show_separator
}

# Privacy validation system for Info.plist compliance using Clean Architecture
validate_privacy_usage_descriptions() {
    local info_plist_path="$1"
    local strict_mode="${2:-false}"
    local validation_mode="${PRIVACY_VALIDATION:-strict}"
    
    # Skip validation if disabled
    if [ "$validation_mode" = "skip" ]; then
        log_info "🔒 Privacy validation skipped (mode: skip)"
        return 0
    fi
    
    log_info "🔒 Privacy Validation (mode: $validation_mode)"
    log_debug "Info.plist path: $info_plist_path"
    
    # Find Info.plist if not provided or not found
    if [ -z "$info_plist_path" ] || [ ! -f "$info_plist_path" ]; then
        log_info "🔍 Searching for Info.plist file..."
        
        # Try common Info.plist locations
        local possible_paths=(
            "./$SCHEME/Info.plist"
            "./$APP_IDENTIFIER/Info.plist"
            "./Info.plist"
            "./$SCHEME.xcodeproj/project.pbxproj"
        )
        
        for path in "${possible_paths[@]}"; do
            if [ -f "$path" ]; then
                info_plist_path="$path"
                log_success "✓ Found Info.plist: $info_plist_path"
                break
            fi
        done
        
        if [ ! -f "$info_plist_path" ]; then
            log_warning "⚠️ Info.plist not found - skipping privacy validation"
            log_info "💡 Ensure Info.plist exists in your project for privacy validation"
            return 0
        fi
    fi
    
    # Create temporary Ruby script for Clean Architecture validation
    local temp_script=$(mktemp /tmp/privacy_validation_XXXXXX.rb)
    local temp_result=$(mktemp /tmp/privacy_result_XXXXXX.json)
    
    cat > "$temp_script" << 'EOF'
#!/usr/bin/env ruby

# Add script directory to load path for Clean Architecture components
script_dir = File.dirname(__FILE__)
lib_path = File.join(script_dir, '..', 'scripts')
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

begin
  require_relative '../scripts/domain/use_cases/validate_privacy_usage_descriptions'
  require 'json'
  
  # Get command line arguments
  info_plist_path = ARGV[0]
  strict_mode = ARGV[1] == 'true'
  result_file = ARGV[2]
  
  # Create validation request
  request = ValidatePrivacyUsageDescriptionsRequest.new(
    info_plist_path: info_plist_path,
    strict_mode: strict_mode
  )
  
  # Execute validation
  use_case = ValidatePrivacyUsageDescriptions.new
  result = use_case.execute(request)
  
  # Write result to file for shell consumption
  File.write(result_file, result.to_json)
  
  # Exit with error code if validation failed
  exit(result.success? ? 0 : 1)
  
rescue StandardError => e
  error_result = {
    success: false,
    errors: [{
      type: 'ruby_execution_error',
      message: "Privacy validation failed: #{e.message}"
    }],
    warnings: [],
    data: {}
  }
  
  File.write(result_file, error_result.to_json)
  exit(1)
end
EOF
    
    # Execute Ruby validation using Clean Architecture
    log_debug "Executing Clean Architecture privacy validation..."
    
    if ruby "$temp_script" "$info_plist_path" "$strict_mode" "$temp_result" 2>/dev/null; then
        validation_success=true
        log_debug "✓ Privacy validation completed successfully"
    else
        validation_success=false
        log_debug "❌ Privacy validation found issues"
    fi
    
    # Parse and display results
    if [ -f "$temp_result" ]; then
        local result_json=$(cat "$temp_result")
        
        # Extract key information using basic JSON parsing
        local error_count=$(echo "$result_json" | grep -o '"errors":\[' | wc -l)
        local warning_count=$(echo "$result_json" | grep -o '"warnings":\[' | wc -l)
        
        # Display validation results
        if [ "$validation_success" = "true" ]; then
            log_success "✅ Privacy validation passed"
            
            # Show any warnings
            if [ "$warning_count" -gt 0 ]; then
                log_warning "⚠️ Found privacy validation warnings - consider addressing for better App Store review experience"
            fi
        else
            log_error "❌ Privacy validation failed"
            log_error "🚨 This may cause TestFlight upload rejection (ITMS-90683)"
            
            # Show fix guidance
            log_info "💡 Fix Instructions:"
            log_info "   1. Open your Info.plist file in Xcode"
            log_info "   2. Add missing privacy usage description keys"
            log_info "   3. Provide clear, user-friendly explanations"
            log_info "   4. Run 'apple-deploy validate_privacy' to verify fixes"
            log_info ""
            log_info "📖 Privacy Guide: https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/requesting_access_to_protected_resources"
            
            # Fail deployment based on validation mode
            if [ "$validation_mode" = "strict" ]; then
                log_error "🛑 Deployment stopped due to privacy validation failure (mode: strict)"
                cleanup_temp_files "$temp_script" "$temp_result"
                return 1
            elif [ "$validation_mode" = "warn" ]; then
                log_warning "⚠️ Continuing deployment despite privacy issues (mode: warn)"
                log_warning "🚨 TestFlight upload may still fail"
            fi
        fi
    else
        log_warning "⚠️ Could not parse privacy validation results"
        if [ "$validation_mode" = "strict" ]; then
            cleanup_temp_files "$temp_script" "$temp_result"
            return 1
        fi
    fi
    
    # Cleanup temporary files
    cleanup_temp_files "$temp_script" "$temp_result"
    
    # Return success unless strict mode validation failed
    if [ "$validation_mode" = "strict" ] && [ "$validation_success" != "true" ]; then
        return 1
    fi
    
    return 0
}

# Helper function to clean up temporary files
cleanup_temp_files() {
    local files=("$@")
    for file in "${files[@]}"; do
        [ -f "$file" ] && rm -f "$file"
    done
}

# Build verification system for IPA integrity and quality assurance
verify_build_integrity() {
    local ipa_path="$1"
    local expected_version="$2"
    local expected_build="$3"
    local verification_errors=0
    
    show_header "🔍 Build Verification System" "🔍"
    log_info "Performing comprehensive build verification..."
    
    if [ -z "$ipa_path" ] || [ ! -f "$ipa_path" ]; then
        log_info "No IPA path provided or file not found, attempting to locate build output..."
        
        # Try to find the most recent IPA file
        local build_dir="./build"
        local derived_data_dir="$HOME/Library/Developer/Xcode/DerivedData"
        
        # Search common build locations
        for search_dir in "$build_dir" "$derived_data_dir" "./"; do
            if [ -d "$search_dir" ]; then
                local found_ipa=$(find "$search_dir" -name "*.ipa" -type f -exec ls -t {} + 2>/dev/null | head -n1)
                if [ -n "$found_ipa" ] && [ -f "$found_ipa" ]; then
                    ipa_path="$found_ipa"
                    log_info "✓ Found IPA file: $(basename "$ipa_path")"
                    break
                fi
            fi
        done
        
        if [ -z "$ipa_path" ] || [ ! -f "$ipa_path" ]; then
            log_warning "No IPA file found for verification - skipping build verification"
            return 0
        fi
    fi
    
    log_debug "Verifying IPA: $ipa_path"
    
    # 1. File existence and basic integrity
    log_info "📋 1/4 Checking file integrity..."
    if [ ! -f "$ipa_path" ]; then
        log_error "IPA file not found: $ipa_path"
        verification_errors=$((verification_errors + 1))
    else
        local file_size=$(du -h "$ipa_path" | cut -f1)
        log_success "✓ IPA file exists ($file_size)"
        
        # Basic file format verification
        if file "$ipa_path" | grep -q "Zip archive"; then
            log_success "✓ IPA file format is valid (ZIP archive)"
        else
            log_error "IPA file format appears invalid"
            verification_errors=$((verification_errors + 1))
        fi
    fi
    
    # 2. IPA structure validation
    log_info "📱 2/4 Validating IPA structure..."
    local temp_extract_dir="/tmp/ipa_verification_$$"
    mkdir -p "$temp_extract_dir"
    
    if unzip -q "$ipa_path" -d "$temp_extract_dir" 2>/dev/null; then
        log_success "✓ IPA archive extracted successfully"
        
        # Check for required structure
        local payload_dir="$temp_extract_dir/Payload"
        if [ -d "$payload_dir" ]; then
            log_success "✓ Payload directory found"
            
            # Find .app bundle
            local app_bundle=$(find "$payload_dir" -name "*.app" -type d | head -n1)
            if [ -n "$app_bundle" ] && [ -d "$app_bundle" ]; then
                log_success "✓ App bundle found: $(basename "$app_bundle")"
                
                # Check for Info.plist
                local info_plist="$app_bundle/Info.plist"
                if [ -f "$info_plist" ]; then
                    log_success "✓ Info.plist found"
                    
                    # Extract version information if available
                    if command -v plutil >/dev/null 2>&1; then
                        local bundle_version=$(plutil -extract CFBundleVersion raw "$info_plist" 2>/dev/null || echo "unknown")
                        local bundle_short_version=$(plutil -extract CFBundleShortVersionString raw "$info_plist" 2>/dev/null || echo "unknown")
                        local bundle_id=$(plutil -extract CFBundleIdentifier raw "$info_plist" 2>/dev/null || echo "unknown")
                        
                        log_info "📋 Bundle Information:"
                        log_info "   • Bundle ID: $bundle_id"
                        log_info "   • Version: $bundle_short_version"
                        log_info "   • Build: $bundle_version"
                        
                        # Version verification if expected values provided
                        if [ -n "$expected_version" ] && [ "$expected_version" != "unknown" ]; then
                            if [ "$bundle_short_version" = "$expected_version" ]; then
                                log_success "✓ Version matches expected: $expected_version"
                            else
                                log_warning "Version mismatch - Expected: $expected_version, Found: $bundle_short_version"
                                verification_errors=$((verification_errors + 1))
                            fi
                        fi
                        
                        if [ -n "$expected_build" ] && [ "$expected_build" != "unknown" ]; then
                            if [ "$bundle_version" = "$expected_build" ]; then
                                log_success "✓ Build number matches expected: $expected_build"
                            else
                                log_warning "Build number mismatch - Expected: $expected_build, Found: $bundle_version"
                                verification_errors=$((verification_errors + 1))
                            fi
                        fi
                    else
                        log_info "plutil not available - skipping detailed plist parsing"
                    fi
                else
                    log_error "Info.plist not found in app bundle"
                    verification_errors=$((verification_errors + 1))
                fi
                
                # Check for executable
                local app_name=$(basename "$app_bundle" .app)
                local executable="$app_bundle/$app_name"
                if [ -f "$executable" ]; then
                    log_success "✓ Main executable found: $app_name"
                else
                    log_error "Main executable not found: $app_name"
                    verification_errors=$((verification_errors + 1))
                fi
            else
                log_error "No .app bundle found in Payload directory"
                verification_errors=$((verification_errors + 1))
            fi
        else
            log_error "Payload directory not found in IPA"
            verification_errors=$((verification_errors + 1))
        fi
    else
        log_error "Failed to extract IPA archive"
        verification_errors=$((verification_errors + 1))
    fi
    
    # 3. Code signing verification
    log_info "🔐 3/4 Verifying code signing..."
    if command -v codesign >/dev/null 2>&1; then
        if codesign --verify --deep --strict "$ipa_path" 2>/dev/null; then
            log_success "✓ Code signing verification passed"
        else
            log_warning "Code signing verification failed or incomplete"
            verification_errors=$((verification_errors + 1))
        fi
        
        # Get signing information
        local signing_info=$(codesign -dv "$ipa_path" 2>&1 | head -n5)
        if [ -n "$signing_info" ]; then
            log_info "🔐 Code Signing Details:"
            echo "$signing_info" | while IFS= read -r line; do
                log_info "   • $line"
            done
        fi
    else
        log_info "codesign not available - skipping code signing verification"
    fi
    
    # 4. Size and performance checks
    log_info "⚡ 4/4 Performance validation..."
    if [ -f "$ipa_path" ]; then
        local size_bytes=$(stat -f%z "$ipa_path" 2>/dev/null || stat -c%s "$ipa_path" 2>/dev/null || echo "0")
        local size_mb=$((size_bytes / 1024 / 1024))
        
        log_info "📊 IPA Size: ${size_mb}MB"
        
        # Size warnings (common App Store guidelines)
        if [ $size_mb -gt 4000 ]; then
            log_warning "IPA size is very large (${size_mb}MB) - may cause App Store submission issues"
        elif [ $size_mb -gt 200 ]; then
            log_info "IPA size is large (${size_mb}MB) - ensure over-the-air downloads are considered"
        else
            log_success "✓ IPA size is reasonable (${size_mb}MB)"
        fi
    fi
    
    # Cleanup temporary extraction
    rm -rf "$temp_extract_dir"
    
    # Final verification result
    echo ""
    if [ $verification_errors -eq 0 ]; then
        log_success "🎉 Build verification completed successfully - No issues found!"
        show_separator "✅"
        return 0
    else
        log_warning "Build verification completed with $verification_errors warning(s)"
        log_info "💡 These are non-critical warnings that don't prevent deployment"
        show_separator "⚠️"
        return 1
    fi
}

# Automated cleanup function for backup and temporary files
cleanup_backup_files() {
    local cleanup_directory="${1:-.}"
    local files_removed=0
    
    log_debug "Starting automated cleanup of backup and temporary files in: $cleanup_directory"
    
    # Clean up backup files with proper globbing
    for pattern in "*.backup" "*_backup" "*.bak" "config.env.backup*" "*.tmp" "*.temp"; do
        # Use find to properly handle patterns
        find "$cleanup_directory" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | while read -r file; do
            if [ -f "$file" ]; then
                log_debug "Removing backup file: $(basename "$file")"
                rm -f "$file"
                files_removed=$((files_removed + 1))
            fi
        done
    done
    
    # Clean up old deployment logs (keep only the current one)
    current_log=$(basename "$LOG_FILE")
    
    # Check both current directory (legacy) and build/logs directory
    for search_dir in "$cleanup_directory" "$cleanup_directory/build/logs"; do
        if [ -d "$search_dir" ]; then
            for log_file in "$search_dir"/deployment_*.log; do
                if [ -f "$log_file" ] && [ "$(basename "$log_file")" != "$current_log" ]; then
                    log_debug "Removing old deployment log: $(basename "$log_file")"
                    rm -f "$log_file"
                    files_removed=$((files_removed + 1))
                fi
            done
        fi
    done
    
    # Clean up FastLane logs (they can accumulate and contain sensitive info)
    for log_file in $cleanup_directory/fastlane_*.log; do
        if [ -f "$log_file" ]; then
            log_debug "Removing FastLane log: $(basename $log_file)"
            rm -f "$log_file"
            files_removed=$((files_removed + 1))
        fi
    done
    
    if [ $files_removed -gt 0 ]; then
        log_info "Cleaned up $files_removed backup/temporary files"
    else
        log_debug "No backup or temporary files found to clean up"
    fi
}

# Comprehensive error messaging system with actionable resolution guidance
show_error_with_resolution() {
    local error_code="$1"
    local error_message="$2"
    local context="$3"
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║ ❌ ERROR ${error_code}: ${error_message}"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    case "$error_code" in
        "E001")
            echo "🔍 PROBLEM: No Xcode project or workspace found"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Navigate to your app directory: cd /path/to/your-app"
            echo "   2. Ensure you have a .xcodeproj or .xcworkspace file"
            echo "   3. Run the deployment from your app's root directory"
            echo ""
            echo "🔧 DETAILED STEPS:"
            echo "   • Check current directory: pwd"
            echo "   • List files: ls -la *.xcode*"
            echo "   • Expected structure: YourApp.xcodeproj or YourApp.xcworkspace"
            echo ""
            echo "📋 CURRENT CONTEXT:"
            echo "   • Current directory: $(pwd)"
            echo "   • Available files: $(ls -1 | head -5 | tr '\n' ', ' | sed 's/,$//')"
            ;;
        "E002")
            echo "🔍 PROBLEM: Missing required team_id parameter"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Add team_id parameter: team_id=\"YOUR_TEAM_ID\""
            echo "   2. Find your Team ID in App Store Connect → Settings → Team ID"
            echo "   3. Team ID format: 10 alphanumeric characters (e.g., YOUR_TEAM_ID)"
            echo ""
            echo "🔧 EXAMPLE USAGE:"
            echo "   ./scripts/deploy.sh build_and_upload \\"
            echo "     team_id=\"YOUR_TEAM_ID\" \\"
            echo "     app_identifier=\"com.yourapp\" \\"
            echo "     apple_id=\"your@email.com\""
            echo ""
            echo "📍 WHERE TO FIND TEAM ID:"
            echo "   • App Store Connect → Settings → General → Team ID"
            echo "   • Apple Developer Portal → Membership → Team ID"
            echo "   • Xcode → Project Settings → Team"
            ;;
        "E003")
            echo "🔍 PROBLEM: Missing or invalid apple_info_dir parameter"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Specify absolute path: apple_info_dir=\"/full/path/to/apple_info\""
            echo "   2. Create directory structure if needed"
            echo "   3. Ensure path starts with / (absolute path required)"
            echo ""
            echo "🔧 RECOMMENDED SETUP:"
            echo "   mkdir -p /Users/\$USER/iOS/private_apple_info"
            echo "   ./scripts/deploy.sh ... apple_info_dir=\"/Users/\$USER/iOS/private_apple_info\""
            echo ""
            echo "📁 EXPECTED DIRECTORY STRUCTURE:"
            echo "   apple_info_dir/"
            echo "   ├── TEAM_ID/"
            echo "   │   ├── AuthKey_*.p8"
            echo "   │   ├── certificates/"
            echo "   │   └── profiles/"
            echo ""
            if [ -n "$context" ]; then
                echo "📋 PROVIDED VALUE: $context"
            fi
            ;;
        "E004")
            echo "🔍 PROBLEM: FastLane execution failed"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Check the FastLane logs above for specific error messages"
            echo "   2. Verify all required parameters are provided and correct"
            echo "   3. Test individual components (certificates, API keys, network)"
            echo ""
            echo "🔧 SYSTEMATIC DEBUGGING:"
            echo "   Step 1: Verify API credentials"
            echo "   • Check API key file exists and is readable"
            echo "   • Verify API key ID and issuer ID are correct"
            echo "   • Test API connectivity with a simple fastlane command"
            echo ""
            echo "   Step 2: Check certificates and profiles"
            echo "   • Run: ./scripts/deploy.sh setup_certificates ..."
            echo "   • Verify certificates are valid and not expired"
            echo "   • Check provisioning profiles match app identifier"
            echo ""
            echo "   Step 3: Test build system"
            echo "   • Open project in Xcode and try manual build"
            echo "   • Check for compilation errors or missing dependencies"
            echo "   • Verify scheme and configuration exist"
            echo ""
            echo "   Step 4: Network and Apple services"
            echo "   • Check internet connectivity"
            echo "   • Verify Apple Developer Portal and App Store Connect are accessible"
            echo "   • Check for Apple service outages: developer.apple.com/system-status"
            echo ""
            if [ -n "$context" ]; then
                echo "📊 EXECUTION DETAILS:"
                echo "   • Exit code: $context"
                echo "   • Failed after: ${STEP5_DURATION:-0} seconds"
                echo "   • Lane: ${LANE:-unknown}"
            fi
            ;;
        "E005")
            echo "🔍 PROBLEM: Certificate or provisioning profile issues"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Re-run certificate setup: ./scripts/deploy.sh setup_certificates ..."
            echo "   2. Check certificate expiration dates"
            echo "   3. Verify provisioning profiles match your app identifier"
            echo ""
            echo "🔧 CERTIFICATE TROUBLESHOOTING:"
            echo "   • Check keychain: security find-identity -v -p codesigning"
            echo "   • Verify P12 files: ls -la apple_info/*/certificates/*.p12"
            echo "   • Check certificate validity: openssl pkcs12 -info -in cert.p12"
            echo ""
            echo "📱 PROVISIONING PROFILE TROUBLESHOOTING:"
            echo "   • List profiles: ls -la apple_info/*/profiles/*.mobileprovision"
            echo "   • Check profile contents: security cms -D -i profile.mobileprovision"
            echo "   • Verify app identifier match in Apple Developer Portal"
            ;;
        "E006")
            echo "🔍 PROBLEM: Network or API connectivity issues"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Check internet connectivity: ping apple.com"
            echo "   2. Verify firewall/proxy settings allow Apple service access"
            echo "   3. Check Apple system status: developer.apple.com/system-status"
            echo ""
            echo "🔧 NETWORK TROUBLESHOOTING:"
            echo "   • Test DNS resolution: nslookup developer.apple.com"
            echo "   • Check HTTPS access: curl -I https://api.appstoreconnect.apple.com"
            echo "   • Verify corporate proxy/VPN settings if applicable"
            echo ""
            echo "🔐 API TROUBLESHOOTING:"
            echo "   • Verify API key permissions in App Store Connect"
            echo "   • Check API key expiration date"
            echo "   • Test with minimal fastlane command: fastlane spaceship list_teams"
            ;;
        "E007")
            echo "🔍 PROBLEM: Build or compilation failure"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Open project in Xcode and attempt manual build"
            echo "   2. Check for missing dependencies or frameworks"
            echo "   3. Verify scheme and build configuration exist"
            echo ""
            echo "🔧 BUILD TROUBLESHOOTING:"
            echo "   • Clean build folder: Product → Clean Build Folder in Xcode"
            echo "   • Check build settings for code signing configuration"
            echo "   • Verify all required SDKs and tools are installed"
            echo "   • Review build logs for specific compilation errors"
            echo ""
            echo "📱 XCODE PROJECT VERIFICATION:"
            echo "   • Scheme exists: Check Product → Scheme → Manage Schemes"
            echo "   • Target settings: Verify bundle identifier, team, certificates"
            echo "   • Dependencies: Ensure all required frameworks are linked"
            ;;
        *)
            echo "🔍 PROBLEM: General error occurred"
            echo ""
            echo "💡 IMMEDIATE SOLUTIONS:"
            echo "   1. Check the error message and logs above"
            echo "   2. Enable debug mode: DEBUG_MODE=true ./scripts/deploy.sh ..."
            echo "   3. Review the session log file for detailed information"
            echo ""
            echo "🔧 GENERAL TROUBLESHOOTING:"
            echo "   • Run with verbose logging: VERBOSE_MODE=true"
            echo "   • Check all required parameters are provided"
            echo "   • Verify file paths and permissions are correct"
            echo "   • Ensure all dependencies (fastlane, xcodebuild) are installed"
            ;;
    esac
    
    echo ""
    echo "📞 NEED MORE HELP?"
    echo "   • Session log: build/logs/$(basename "$LOG_FILE")"
    echo "   • Enable debug mode: DEBUG_MODE=true ./scripts/deploy.sh ..."
    echo "   • Run status check: ./scripts/deploy.sh status ..."
    echo ""
}

# Intelligent error detection and categorization
detect_error_type() {
    local exit_code="$1"
    local log_content="$2"
    
    # Check for specific error patterns in logs and exit codes
    if echo "$log_content" | grep -i "certificate.*expired\|certificate.*invalid\|provisioning.*expired" >/dev/null 2>&1; then
        echo "E005"
    elif echo "$log_content" | grep -i "network.*error\|connection.*failed\|timeout\|dns.*error" >/dev/null 2>&1; then
        echo "E006"
    elif echo "$log_content" | grep -i "build.*failed\|compilation.*error\|linker.*error\|missing.*framework" >/dev/null 2>&1; then
        echo "E007"
    elif echo "$log_content" | grep -i "api.*key\|authentication.*failed\|unauthorized\|forbidden" >/dev/null 2>&1; then
        echo "E006"
    elif [ "$exit_code" -ne 0 ]; then
        echo "E004"
    else
        echo "E000"
    fi
}

# Network and API connectivity validation
validate_network_connectivity() {
    local network_errors=0
    
    echo "🌐 Testing network connectivity..."
    
    # Test basic internet connectivity
    if ! ping -c 1 -W 3000 8.8.8.8 >/dev/null 2>&1; then
        log_warning "Basic internet connectivity test failed (non-critical)"
        echo "   ⚠️  Unable to reach 8.8.8.8 - check internet connection (non-critical)"
        # Don't increment network_errors - deployment can still work
    else
        log_debug "✓ Basic internet connectivity confirmed"
    fi
    
    # Test Apple service connectivity
    log_debug "Testing Apple service connectivity..."
    
    # Test Apple Developer Portal
    if ! curl -I -s -m 10 --connect-timeout 5 "https://developer.apple.com" | head -n1 | grep -q "200\|301\|302" 2>/dev/null; then
        log_warning "Apple Developer Portal connectivity test failed (non-critical)"
        echo "   ⚠️  Unable to reach developer.apple.com (non-critical)"
        # Don't increment network_errors - deployment can still work
    else
        log_debug "✓ Apple Developer Portal accessible"
    fi
    
    # Test App Store Connect API
    if ! curl -I -s -m 10 --connect-timeout 5 "https://api.appstoreconnect.apple.com" | head -n1 | grep -q "200\|401\|403" 2>/dev/null; then
        log_warning "App Store Connect API connectivity test failed (non-critical)"
        echo "   ⚠️  Unable to reach api.appstoreconnect.apple.com (non-critical)"
        # Don't increment network_errors - this is non-critical
    else
        log_debug "✓ App Store Connect API accessible"
    fi
    
    # Test iTunes Connect (for legacy operations)
    if ! curl -I -s -m 10 --connect-timeout 5 "https://itunesconnect.apple.com" | head -n1 | grep -q "200\|301\|302" 2>/dev/null; then
        log_warning "iTunes Connect connectivity test failed (non-critical)"
        echo "   ⚠️  Unable to reach itunesconnect.apple.com (non-critical)"
    else
        log_debug "✓ iTunes Connect accessible"
    fi
    
    if [ $network_errors -gt 0 ]; then
        echo ""
        echo "🔧 NETWORK TROUBLESHOOTING SUGGESTIONS:"
        echo "   1. Check internet connection and DNS settings"
        echo "   2. Verify firewall/proxy settings allow Apple service access"
        echo "   3. Check Apple system status: https://www.apple.com/support/systemstatus/"
        echo "   4. Try connecting from different network (cellular/VPN)"
        echo "   5. Check corporate network restrictions if applicable"
        echo ""
    fi
    
    return $network_errors
}

# API key and authentication validation
validate_api_credentials() {
    local api_errors=0
    
    echo "🔐 Validating API credentials..."
    
    # Check API key file exists and is readable
    if [ -z "$API_KEY_PATH" ]; then
        log_error "API key path not provided"
        api_errors=$((api_errors + 1))
    elif [ ! -f "$API_KEY_PATH" ]; then
        log_error "API key file not found: $API_KEY_PATH"
        api_errors=$((api_errors + 1))
    elif [ ! -r "$API_KEY_PATH" ]; then
        log_error "API key file not readable: $API_KEY_PATH"
        api_errors=$((api_errors + 1))
    else
        log_debug "✓ API key file found and readable"
        
        # Check file format (should be .p8)
        if [[ "$API_KEY_PATH" != *.p8 ]]; then
            log_warning "API key file should have .p8 extension: $API_KEY_PATH"
            echo "   ⚠️  Expected format: AuthKey_XXXXXXXXXX.p8"
        fi
        
        # Check file size (should be reasonable for a .p8 key)
        file_size=$(stat -f%z "$API_KEY_PATH" 2>/dev/null || stat -c%s "$API_KEY_PATH" 2>/dev/null || echo 0)
        if [ "$file_size" -lt 100 ] || [ "$file_size" -gt 2000 ]; then
            log_warning "API key file size seems unusual: ${file_size} bytes"
            echo "   ⚠️  Expected size: 200-800 bytes for valid .p8 key"
        fi
    fi
    
    # Validate API key ID format
    if [ -z "$API_KEY_ID" ]; then
        log_error "API key ID not provided"
        api_errors=$((api_errors + 1))
    elif ! echo "$API_KEY_ID" | grep -qE '^[A-Z0-9]{10}$'; then
        log_warning "API key ID format may be incorrect: $API_KEY_ID"
        echo "   ⚠️  Expected format: 10 alphanumeric characters (e.g., ABCD123456)"
    else
        log_debug "✓ API key ID format looks valid"
    fi
    
    # Validate API issuer ID format (UUID)
    if [ -z "$API_ISSUER_ID" ]; then
        log_error "API issuer ID not provided"
        api_errors=$((api_errors + 1))
    elif ! echo "$API_ISSUER_ID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
        log_warning "API issuer ID format may be incorrect: $API_ISSUER_ID"
        echo "   ⚠️  Expected format: UUID (e.g., 12345678-1234-1234-1234-123456789012)"
    else
        log_debug "✓ API issuer ID format looks valid"
    fi
    
    # Test basic API authentication if fastlane is available
    if command -v fastlane >/dev/null 2>&1 && [ $api_errors -eq 0 ]; then
        echo "   🔍 Testing API authentication..."
        
        # Create temporary directory for test
        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        # Test basic API connectivity with a simple command
        if timeout 30 fastlane spaceship list_teams --api_key_path "$API_KEY_PATH" --api_key_id "$API_KEY_ID" --api_issuer_id "$API_ISSUER_ID" >/dev/null 2>&1; then
            log_success "✓ API authentication test successful"
        else
            log_warning "API authentication test failed or timed out (non-critical)"
            echo "   ⚠️  This could indicate API key permissions or connectivity issues"
            echo "   ⚠️  Deployment may still succeed if API key has correct permissions"
            # Don't increment api_errors - this is non-critical, actual deployment will test properly
        fi
        
        # Clean up
        cd - >/dev/null
        rm -rf "$temp_dir"
    fi
    
    return $api_errors
}

# Development environment validation
validate_development_environment() {
    local env_errors=0
    
    echo "🛠️  Validating development environment..."
    
    # Check Xcode installation
    if command -v xcodebuild >/dev/null 2>&1; then
        xcode_version=$(xcodebuild -version | head -n1 2>/dev/null || echo "Unknown")
        log_debug "✓ Xcode found: $xcode_version"
        
        # Check if command line tools are properly set
        if ! xcode-select -p >/dev/null 2>&1; then
            log_warning "Xcode command line tools path not set"
            echo "   ⚠️  Run: sudo xcode-select --install"
            env_errors=$((env_errors + 1))
        else
            dev_dir=$(xcode-select -p)
            log_debug "✓ Command line tools path: $dev_dir"
        fi
        
        # Check if we can list SDKs
        if xcodebuild -showsdks >/dev/null 2>&1; then
            ios_sdk_count=$(xcodebuild -showsdks 2>/dev/null | grep -c "iOS" || echo "0")
            log_debug "✓ iOS SDKs available: $ios_sdk_count"
        else
            log_warning "Unable to list Xcode SDKs (non-critical)"
            # Don't increment errors - deployment may still work
        fi
    else
        show_error_with_resolution "E007" "Xcode not found" "Missing development tools"
        env_errors=$((env_errors + 1))
    fi
    
    # Check Ruby/gem environment for fastlane
    if command -v ruby >/dev/null 2>&1; then
        ruby_version=$(ruby --version | cut -d' ' -f2)
        log_debug "✓ Ruby version: $ruby_version"
        
        if command -v gem >/dev/null 2>&1; then
            if command -v fastlane >/dev/null 2>&1; then
                fastlane_version=$(fastlane --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
                log_debug "✓ FastLane version: $fastlane_version"
            else
                log_error "FastLane not installed"
                echo "   💡 Install: gem install fastlane"
                env_errors=$((env_errors + 1))
            fi
        else
            log_warning "Gem package manager not available"
            env_errors=$((env_errors + 1))
        fi
    else
        log_warning "Ruby not found - may affect fastlane functionality"
        env_errors=$((env_errors + 1))
    fi
    
    # Check available disk space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df -h . | tail -n1 | awk '{print $4}' | sed 's/[^0-9.]//g')
        if [ -n "$available_space" ] && [ "${available_space%.*}" -lt 5 ]; then
            log_warning "Low disk space available: ${available_space}GB"
            echo "   ⚠️  Consider freeing up space before large builds"
        else
            log_debug "✓ Sufficient disk space available: ${available_space}GB"
        fi
    fi
    
    return $env_errors
}

# Project-specific validation  
validate_project_configuration() {
    local project_errors=0
    
    echo "📱 Validating project configuration..."
    
    # Validate app identifier format
    if [ -n "$APP_IDENTIFIER" ]; then
        if echo "$APP_IDENTIFIER" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+$'; then
            log_debug "✓ App identifier format looks valid: $APP_IDENTIFIER"
        else
            log_warning "App identifier format may be incorrect: $APP_IDENTIFIER"
            echo "   ⚠️  Expected format: com.company.appname"
        fi
    fi
    
    # Validate team ID format
    if [ -n "$TEAM_ID" ]; then
        if echo "$TEAM_ID" | grep -qE '^[A-Z0-9]{10}$'; then
            log_debug "✓ Team ID format looks valid: $TEAM_ID"
        else
            log_warning "Team ID format may be incorrect: $TEAM_ID"
            echo "   ⚠️  Expected format: 10 alphanumeric characters (e.g., ABC123DEF4)"
        fi
    fi
    
    # Check project structure for build lanes
    if [[ "$LANE" == "build_and_upload" ]]; then
        project_files=$(find . -maxdepth 1 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \))
        project_count=$(echo "$project_files" | grep -c . || echo 0)
        
        if [ "$project_count" -eq 0 ]; then
            show_error_with_resolution "E001" "No Xcode project found for build" "$(pwd)"
            project_errors=$((project_errors + 1))
        elif [ "$project_count" -gt 1 ]; then
            log_warning "Multiple Xcode projects/workspaces found:"
            echo "$project_files" | sed 's/^/     /'
            echo "   ⚠️  Make sure you're in the correct app directory"
        else
            project_file=$(echo "$project_files" | head -n1)
            log_debug "✓ Found project: $(basename "$project_file")"
            
            # For .xcodeproj, check if scheme exists
            if [[ "$project_file" == *.xcodeproj ]] && [ -n "$SCHEME" ]; then
                if xcodebuild -project "$project_file" -list 2>/dev/null | grep -q "Schemes:" && 
                   xcodebuild -project "$project_file" -list 2>/dev/null | grep -q "^        $SCHEME$"; then
                    log_debug "✓ Scheme '$SCHEME' found in project"
                else
                    log_warning "Scheme '$SCHEME' not found in project (non-critical)"
                    echo "   💡 Available schemes:"
                    xcodebuild -project "$project_file" -list 2>/dev/null | sed -n '/Schemes:/,/^$/p' | grep "^        " | sed 's/^        /     - /' 2>/dev/null || echo "     - Unable to list schemes"
                    # Don't increment errors - scheme may still work
                fi
            fi
        fi
    fi
    
    return $project_errors
}

# Simplified validation focusing on critical deployment requirements
validate_deployment_environment() {
    local validation_errors=0
    
    show_header "PRE-FLIGHT VALIDATION (Essential Checks Only)" "🔍"
    
    # Only check absolutely critical requirements
    show_section "Checking essential tools" "🛠️"
    
    # Check FastLane availability (critical)
    if ! command -v fastlane >/dev/null 2>&1; then
        log_error "FastLane not found in PATH"
        show_error_with_resolution "E000" "FastLane not found" "gem install fastlane"
        validation_errors=$((validation_errors + 1))
    else
        log_debug "✓ FastLane available"
    fi
    
    # Check Xcode availability (critical)  
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log_error "Xcode command line tools not found"
        show_error_with_resolution "E007" "Xcode not found" "xcode-select --install"
        validation_errors=$((validation_errors + 1))
    else
        log_debug "✓ Xcode command line tools available"
    fi
    
    show_section "Checking required parameters" "🔐"
    
    # Check critical parameters
    if [ -z "$APP_IDENTIFIER" ]; then
        log_error "Missing app_identifier parameter"
        validation_errors=$((validation_errors + 1))
    else
        log_debug "✓ App identifier provided: $APP_IDENTIFIER"
    fi
    
    if [ -z "$TEAM_ID" ]; then
        log_error "Missing team_id parameter"  
        validation_errors=$((validation_errors + 1))
    else
        log_debug "✓ Team ID provided: $TEAM_ID"
    fi
    
    if [ -z "$API_KEY_PATH" ] || [ ! -f "$API_KEY_PATH" ]; then
        log_error "API key file not found: $API_KEY_PATH"
        validation_errors=$((validation_errors + 1))
    else
        log_debug "✓ API key file found: $API_KEY_PATH"
    fi
    
    # Network connectivity warning (non-blocking)
    show_section "Testing connectivity (informational only)" "🌐"
    if ! ping -c 1 -W 3000 8.8.8.8 >/dev/null 2>&1; then
        log_warning "Internet connectivity test failed (non-critical)"
    else
        log_debug "✓ Internet connectivity confirmed"
    fi
    
    # Summary
    if [ $validation_errors -eq 0 ]; then
        show_result_summary "true" "PRE-FLIGHT VALIDATION PASSED - Ready to deploy"
    else
        local details="🔧 REQUIRED ACTIONS:
   1. Fix all ERROR messages above before deployment
   2. WARNING messages are informational only"
        show_result_summary "false" "PRE-FLIGHT VALIDATION FAILED - $validation_errors critical issue(s)" "$details"
    fi
    
    # Return validation result
    return $validation_errors
}

# Unified validation function using Clean Architecture
validate_deployment_environment_unified() {
    local validation_result=0
    
    show_header "COMPREHENSIVE VALIDATION SUITE" "🛡️"
    
    # Create temporary file for Ruby use case execution
    local temp_validation_file="/tmp/apple_deploy_validation_$$.rb"
    local temp_result_file="/tmp/apple_deploy_validation_result_$$.json"
    
    # Build validation request parameters
    local validation_request="{"
    [ -n "$APP_IDENTIFIER" ] && validation_request+='"app_identifier": "'$APP_IDENTIFIER'",'
    [ -n "$TEAM_ID" ] && validation_request+='"team_id": "'$TEAM_ID'",'
    [ -n "$SCHEME" ] && validation_request+='"scheme": "'$SCHEME'",'
    [ -n "$APPLE_INFO_BASE_DIR" ] && validation_request+='"apple_info_dir": "'$APPLE_INFO_BASE_DIR'",'
    validation_request+='"mode": "'$VALIDATION_MODE'",'
    validation_request+='"strict_mode": '$VALIDATION_STRICT','
    validation_request+='"project_directory": "."'
    validation_request+="}"
    
    # Create Ruby execution script for Clean Architecture integration
    cat > "$temp_validation_file" << 'RUBY_EOF'
#!/usr/bin/env ruby
# Unified Validation Execution Script for Clean Architecture Integration

require 'json'
require 'time'

# Add scripts directory to load path - use absolute path for temp file execution
scripts_base_dir = ENV['APPLE_DEPLOY_SCRIPTS_DIR'] || '/Users/avilevin/Workspace/iOS/Personal/ios-deploy-platform/scripts'
$LOAD_PATH.unshift(scripts_base_dir)

begin
  require File.join(scripts_base_dir, 'domain/use_cases/validate_deployment_environment')
  
  # Get validation parameters from environment or command line
  request_json = ARGV[0] || ENV['VALIDATION_REQUEST'] || '{}'
  request_params = JSON.parse(request_json, symbolize_names: true)
  
  # Create validation request
  validation_request = ValidateDeploymentEnvironmentRequest.new(
    app_identifier: request_params[:app_identifier],
    team_id: request_params[:team_id],
    scheme: request_params[:scheme],
    project_directory: request_params[:project_directory] || '.',
    apple_info_dir: request_params[:apple_info_dir],
    mode: request_params[:mode] || 'full',
    strict_mode: request_params[:strict_mode] || false
  )
  
  # Execute validation use case
  use_case = ValidateDeploymentEnvironment.new
  result = use_case.execute(validation_request)
  
  # Output result as JSON for shell script consumption
  output = {
    success: result.success?,
    errors: result.errors,
    warnings: result.warnings,
    data: result.data,
    timestamp: Time.now.utc.iso8601
  }
  
  puts JSON.pretty_generate(output)
  
  # Exit with appropriate code
  exit(result.success? ? 0 : 1)
  
rescue StandardError => e
  # Handle any errors in validation execution
  error_output = {
    success: false,
    errors: [{
      type: 'execution_error',
      message: "Validation execution failed: #{e.message}",
      technical_details: e.backtrace&.first(3)
    }],
    warnings: [],
    data: { execution_error: true },
    timestamp: Time.now.utc.iso8601
  }
  
  puts JSON.pretty_generate(error_output)
  exit 1
end
RUBY_EOF
    
    # Make validation script executable
    chmod +x "$temp_validation_file"
    
    # Execute Clean Architecture validation
    show_status "info" "🔄 Executing comprehensive validation suite..."
    
    # Set environment variable for scripts directory
    export APPLE_DEPLOY_SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
    
    # Try Clean Architecture validation first, fallback to shell validation
    if ruby "$temp_validation_file" "$validation_request" > "$temp_result_file" 2>&1; then
        validation_result=0
        
        # Parse and display results
        if command -v jq >/dev/null 2>&1; then
            # Enhanced results display with jq
            local domain_results=$(cat "$temp_result_file" | jq -r '.data.domain_results // {}' 2>/dev/null)
            local success_rate=$(cat "$temp_result_file" | jq -r '.data.success_rate // 0' 2>/dev/null)
            
            show_status "success" "🎉 Unified validation completed successfully"
            show_status "info" "📊 Success Rate: ${success_rate}%"
            
            # Display domain-specific results
            if [ -n "$domain_results" ] && [ "$domain_results" != "{}" ]; then
                show_section "Validation Results by Domain" "📋"
                echo "$domain_results" | jq -r 'to_entries[] | "  \(.key): \(if .value.success then "✅ PASS" else "❌ FAIL" end)"' 2>/dev/null || true
            fi
        else
            # Fallback display without jq
            show_status "success" "🎉 Unified validation completed successfully"
            if [ -s "$temp_result_file" ]; then
                show_status "info" "📊 Detailed results available in validation output"
            fi
        fi
        
        # Display next steps from validation result
        if command -v jq >/dev/null 2>&1; then
            local next_actions=$(cat "$temp_result_file" | jq -r '.data.next_actions[]?.message // empty' 2>/dev/null)
            if [ -n "$next_actions" ]; then
                show_section "Recommended Actions" "💡"
                echo "$next_actions" | while read -r action; do
                    [ -n "$action" ] && log_info "  • $action"
                done
            fi
        fi
    else
        validation_result=1
        
        show_status "error" "❌ Unified validation failed"
        
        # Display errors from validation result
        if [ -s "$temp_result_file" ] && command -v jq >/dev/null 2>&1; then
            local errors=$(cat "$temp_result_file" | jq -r '.errors[]?.message // empty' 2>/dev/null)
            if [ -n "$errors" ]; then
                show_section "Validation Errors" "🚨"
                echo "$errors" | while read -r error; do
                    [ -n "$error" ] && log_error "  • $error"
                done
            fi
            
            local warnings=$(cat "$temp_result_file" | jq -r '.warnings[]?.message // empty' 2>/dev/null)
            if [ -n "$warnings" ]; then
                show_section "Validation Warnings" "⚠️"
                echo "$warnings" | while read -r warning; do
                    [ -n "$warning" ] && log_warning "  • $warning"
                done
            fi
        else
            # Fallback error display
            show_status "error" "🔧 Clean Architecture validation failed, falling back to legacy validation"
            if [ -s "$temp_result_file" ]; then
                log_error "Ruby validation error:"
                cat "$temp_result_file" | head -10
            fi
            
            # Run fallback shell-based validation
            show_status "info" "🔄 Running fallback validation using shell functions..."
            fallback_validation_result=0
            
            # Run existing validation functions based on mode
            case $VALIDATION_MODE in
                "quick")
                    show_section "Quick Validation" "🏃‍♂️"
                    if ! validate_network_connectivity; then
                        fallback_validation_result=1
                    fi
                    if ! validate_deployment_environment; then
                        fallback_validation_result=1
                    fi
                    ;;
                "comprehensive")
                    show_section "Comprehensive Validation" "🔬"
                    if ! validate_deployment_environment; then
                        fallback_validation_result=1
                    fi
                    if ! validate_network_connectivity; then
                        fallback_validation_result=1
                    fi
                    if [ -n "$APP_IDENTIFIER" ] && [ -n "$SCHEME" ]; then
                        if ! validate_privacy_usage_descriptions; then
                            fallback_validation_result=1
                        fi
                    fi
                    if ! validate_api_credentials; then
                        fallback_validation_result=1
                    fi
                    ;;
                *)
                    show_section "Full Validation" "🎯"
                    if ! validate_deployment_environment; then
                        fallback_validation_result=1
                    fi
                    if ! validate_network_connectivity; then
                        fallback_validation_result=1
                    fi
                    if [ -n "$APP_IDENTIFIER" ] && [ -n "$SCHEME" ]; then
                        if ! validate_privacy_usage_descriptions; then
                            fallback_validation_result=1
                        fi
                    fi
                    ;;
            esac
            
            validation_result=$fallback_validation_result
        fi
    fi
    
    # Clean up temporary files
    [ -f "$temp_validation_file" ] && rm -f "$temp_validation_file"
    [ -f "$temp_result_file" ] && rm -f "$temp_result_file"
    
    # Display validation summary
    if [ $validation_result -eq 0 ]; then
        show_result_summary "true" "COMPREHENSIVE VALIDATION SUCCESSFUL - Environment ready for deployment!"
    else
        local details="🔧 REQUIRED ACTIONS:
   1. Fix validation errors listed above
   2. Re-run validation: apple-deploy validate [same parameters]
   3. For specific guidance: apple-deploy help"
        show_result_summary "false" "COMPREHENSIVE VALIDATION FAILED - Issues require attention" "$details"
    fi
    
    return $validation_result
}

# Enhanced progress reporting functions
show_progress_header() {
    local step_num=$1
    local step_title="$2"
    local estimated_time="$3"
    
    CURRENT_STEP=$step_num
    local current_time=$(date +%s)
    local elapsed=$((current_time - DEPLOYMENT_START_TIME))
    local progress_emoji=${PROGRESS_EMOJIS[$((step_num - 1))]}
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║ ${progress_emoji} STEP ${step_num}/${TOTAL_STEPS}: ${step_title}"
    echo "║ ⏱️  Estimated time: ${estimated_time} | Elapsed: ${elapsed}s"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r🚀 Progress: ["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %d%% (%d/%d)" $percentage $current $total
}

show_step_completion() {
    local step_num=$1
    local step_title="$2"
    local success=$3
    local duration="$4"
    
    if [ "$success" = "true" ]; then
        show_status "success" "STEP ${step_num} COMPLETED: ${step_title} (${duration}s)"
        show_progress_bar $step_num $TOTAL_STEPS
        echo ""
    else
        show_status "error" "STEP ${step_num} FAILED: ${step_title} (${duration}s)"
    fi
}

estimate_remaining_time() {
    local current_step=$1
    local current_time=$(date +%s)
    local elapsed=$((current_time - DEPLOYMENT_START_TIME))
    
    if [ $current_step -gt 0 ]; then
        local avg_time_per_step=$((elapsed / current_step))
        local remaining_steps=$((TOTAL_STEPS - current_step))
        local estimated_remaining=$((avg_time_per_step * remaining_steps))
        echo "⏰ Estimated remaining time: ${estimated_remaining}s"
    fi
}

# Enhanced logging banner
if [ "$DEBUG_MODE" = "true" ] || [ "$VERBOSE_MODE" = "true" ]; then
    echo "📝 Enhanced logging enabled"
    echo "🔍 Debug mode: $DEBUG_MODE"
    echo "📢 Verbose mode: $VERBOSE_MODE"
    echo "📄 Log file: $LOG_FILE"
    log_info "Deployment session started with enhanced logging"
fi

# Show help if requested
if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "🚀 iOS Publishing Automation Platform - Deploy Script"
    echo "============================================================"
    echo ""
    echo "Usage:"
    echo "  ./scripts/deploy.sh [lane] [parameters...]"
    echo ""
    echo "Lanes:"
    echo "  build_and_upload      - Complete build and TestFlight upload (default)"
    echo "  setup_certificates    - Setup certificates and provisioning profiles"
    echo "                          (Team mode: auto-detects P12 files for import vs creation)"
    echo "  setup_team_certificates - Explicit team collaboration certificate setup"
    echo "  validate_machine_certificates - Pre-build certificate validation for machine independence"
    echo "  refresh_stale_certificates - Detect and refresh stale certificates for team sync"
    echo "  query_live_marketing_versions - Query App Store Connect for live marketing versions"
    echo "  detect_marketing_version_conflicts - Check for version conflicts with App Store"
    echo "  validate_marketing_version_with_resolution - Auto-resolve marketing version conflicts"
    echo "  smart_marketing_version_increment - Intelligent version increment with App Store sync"
    echo "  check_testflight_status_standalone - Check latest TestFlight build status with enhanced details"
    echo "  validate              - Run comprehensive pre-deployment validation (environment, network, API, privacy, certificates)"
    echo "  validate_privacy      - Validate privacy usage descriptions (prevent ITMS-90683 errors)"
    echo "  verify_build          - Standalone build verification (IPA integrity, structure, signing)"
    echo "  status                - Show certificate and profile status"
    echo "  cleanup               - Clean certificates and profiles"
    echo ""
    echo "Parameters (override defaults and config.env):"
    echo "  app_identifier=\"com.example.app\"    - Your app's bundle ID"
    echo "  apple_id=\"your@email.com\"          - Apple Developer account email"
    echo "  team_id=\"YOUR_TEAM_ID\"             - Apple Developer Team ID"
    echo "  api_key_id=\"YOUR_KEY_ID\"           - App Store Connect API Key ID"
    echo "  api_issuer_id=\"your-issuer-id\"      - App Store Connect API Issuer ID"
    echo "  api_key_path=\"AuthKey_XXXXX.p8\"     - Path to API key file (auto-detected in apple_info_dir/team_id/)"
    echo "  app_name=\"Your App Name\"           - Display name for your app"
    echo "  scheme=\"YourScheme\"                - Xcode scheme to build"
    echo "  configuration=\"Release\"            - Build configuration"
    echo "  p12_password=\"YourPassword\"        - P12 certificate password (default: auto-generated)"
    echo "  version_bump=\"major|minor|patch\"   - Marketing version increment type"
    echo "  testflight_enhanced=\"true|false\"   - Enable extended TestFlight confirmation & enhanced logging (default: false)"
    echo "  privacy_validation=\"strict|warn|skip\"   - Privacy usage descriptions validation mode (default: strict)"
    echo ""
    echo "Build Verification Parameters (for verify_build command):"
    echo "  ipa_path=\"/path/to/app.ipa\"         - Path to IPA file (auto-detected if not provided)"
    echo "  expected_version=\"1.0.0\"           - Expected version for verification"
    echo "  expected_build=\"123\"               - Expected build number for verification"
    echo ""
    echo "Validation Parameters (for validate command):"
    echo "  mode=\"quick|full|comprehensive\"    - Validation scope (default: full)"
    echo "  strict=\"true|false\"                - Treat warnings as errors (default: false)"  
    echo "  app_identifier=\"com.your.app\"      - Bundle identifier for app-specific validation"
    echo "  team_id=\"ABC1234567\"               - Team ID for certificate validation"
    echo "  scheme=\"YourScheme\"                - Xcode scheme for project validation"
    echo "  apple_info_dir=\"/path/to/info\"     - Apple info directory path"
    echo "  quick=\"true\"                       - Shortcut for mode=\"quick\""
    echo "  comprehensive=\"true\"               - Shortcut for mode=\"comprehensive\""
    echo ""
    echo "Logging Options (environment variables):"
    echo "  DEBUG_MODE=true                      - Enable detailed debug logging"
    echo "  VERBOSE_MODE=true                    - Enable verbose output and logging"
    echo "  Both modes create timestamped log files for troubleshooting"
    echo "  apple_info_dir=\"/shared/teams\"       - Apple info base directory (REQUIRED - no default)"
    echo "  api_key_path=\"AuthKey_XXXXX.p8\"     - API key file (auto-detected in apple_info_dir/team_id/)"
    echo "  certificates_dir=\"./certificates\"  - Custom certificates directory (optional)"
    echo "  profiles_dir=\"./profiles\"          - Custom profiles directory (optional)"
    echo ""
    echo "Multi-Team Directory Structure (v1.6):"
    echo "  🏢 Team-Based Pattern: Navigate to app directory, each team isolated by team_id"
    echo "     - Run from: cd /path/to/your-app && ../scripts/deploy.sh"
    echo "     - API keys (.p8): apple_info/TEAM_ID/AuthKey_*.p8 (auto-detected)"
    echo "     - Certificates: apple_info/TEAM_ID/certificates/*.p12"
    echo "     - Profiles: apple_info/TEAM_ID/profiles/*.mobileprovision"
    echo "     - Configuration: apple_info/TEAM_ID/certificates/config.env"
    echo "  🌐 Enterprise Pattern: Use shared apple_info_dir for multiple teams"
    echo "     - Shared location: apple_info_dir=\"/shared/ios-teams\""
    echo "     - Teams isolated: /shared/ios-teams/TEAM_ID/{certificates,profiles}"
    echo ""
    echo "Examples:"
    echo "  # Multi-team deployment (navigate to app directory first):"
    echo "  cd /path/to/your-app"
    echo "  ../scripts/deploy.sh build_and_upload \\"
    echo "    team_id=\"YOUR_TEAM_ID\" \\"
    echo "    app_identifier=\"com.babynetwork.app\" \\"
    echo "    apple_id=\"dev@babynetwork.com\" \\"
    echo "    api_key_path=\"AuthKey_XXXXX.p8\" \\"
    echo "    api_key_id=\"YOUR_KEY_ID\" \\"
    echo "    api_issuer_id=\"your-issuer-uuid\" \\"
    echo "    app_name=\"Baby Network App\" \\"
    echo "    scheme=\"YourScheme\""
    echo ""
    echo "  # Enterprise shared apple_info:"
    echo "  cd /path/to/your-app"
    echo "  ../scripts/deploy.sh build_and_upload \\"
    echo "    team_id=\"ABC1234567\" \\"
    echo "    apple_info_dir=\"/shared/ios-teams\" \\"
    echo "    app_identifier=\"com.applicaster.app\" \\"
    echo "    apple_id=\"dev@applicaster.com\" \\"
    echo "    app_name=\"Applicaster App\""
    echo ""
    echo "  # Version increment examples:"
    echo "  ../scripts/deploy.sh build_and_upload team_id=\"YOUR_TEAM_ID\" version_bump=\"major\"   # 1.0.0 → 2.0.0"
    echo "  ../scripts/deploy.sh build_and_upload team_id=\"YOUR_TEAM_ID\" version_bump=\"minor\"   # 1.0.0 → 1.1.0"
    echo "  ../scripts/deploy.sh build_and_upload team_id=\"YOUR_TEAM_ID\" version_bump=\"patch\"   # 1.0.0 → 1.0.1"
    echo ""
    echo "  # Enhanced TestFlight examples:"
    echo "  ../scripts/deploy.sh build_and_upload team_id=\"YOUR_TEAM_ID\" testflight_enhanced=\"true\"  # Extended confirmation & logging"
    echo "  ../scripts/deploy.sh check_testflight_status_standalone team_id=\"YOUR_TEAM_ID\"            # Manual status check"
    echo ""
    echo "  # Validation examples:"
    echo "  ../scripts/deploy.sh validate                                        # Full validation suite"
    echo "  ../scripts/deploy.sh validate mode=\"quick\"                          # Quick validation (environment + network)"
    echo "  ../scripts/deploy.sh validate mode=\"comprehensive\" team_id=\"YOUR_TEAM_ID\" scheme=\"MyApp\"  # Deep validation"
    echo "  ../scripts/deploy.sh validate strict=\"true\" app_identifier=\"com.your.app\"  # Strict mode (warnings as errors)"
    echo "  ../scripts/deploy.sh validate_privacy scheme=\"MyApp\"                # Privacy validation only"
    echo "  ../scripts/deploy.sh verify_build scheme=\"MyApp\"                    # Build verification only"
    echo ""
    echo "Note: Parameters override config.env values, which override script defaults."
    exit 0
fi

# Parse command line arguments
LANE="${1:-build_and_upload}"

# Handle special validation command
if [ "$LANE" = "validate" ]; then
    show_header "COMPREHENSIVE PRE-DEPLOYMENT VALIDATION" "🛡️"
    show_status "info" "This will test your environment, network, API credentials, privacy, and certificates"
    show_status "info" "before attempting a deployment. No actual deployment will be performed."
    
    # Parse parameters for unified validation
    shift # Remove the lane parameter
    VALIDATION_MODE="full"  # Default mode
    VALIDATION_STRICT="false"
    VALIDATION_QUICK="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            app_identifier=*)
                APP_IDENTIFIER="${1#*=}"
                shift
                ;;
            team_id=*)
                TEAM_ID="${1#*=}"
                shift
                ;;
            scheme=*)
                SCHEME="${1#*=}"
                shift
                ;;
            apple_info_dir=*)
                APPLE_INFO_BASE_DIR="${1#*=}"
                shift
                ;;
            mode=*)
                VALIDATION_MODE="${1#*=}"
                shift
                ;;
            strict=* | strict_mode=*)
                VALIDATION_STRICT="${1#*=}"
                shift
                ;;
            quick=*)
                if [ "${1#*=}" = "true" ]; then
                    VALIDATION_MODE="quick"
                    VALIDATION_QUICK="true"
                fi
                shift
                ;;
            comprehensive=*)
                if [ "${1#*=}" = "true" ]; then
                    VALIDATION_MODE="comprehensive"
                fi
                shift
                ;;
            api_key_path=* | api_key_id=* | api_issuer_id=*)
                # Parse legacy API parameters for compatibility
                case $1 in
                    api_key_path=*) API_KEY_PATH="${1#*=}" ;;
                    api_key_id=*) API_KEY_ID="${1#*=}" ;;
                    api_issuer_id=*) API_ISSUER_ID="${1#*=}" ;;
                esac
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Display validation mode
    case $VALIDATION_MODE in
        "quick")
            show_status "info" "🏃‍♂️ Quick Mode: Environment and network checks only (30-60 seconds)"
            ;;
        "comprehensive")
            show_status "info" "🔬 Comprehensive Mode: All validations + deep project analysis (2-3 minutes)"
            ;;
        *)
            VALIDATION_MODE="full"
            show_status "info" "🎯 Full Mode: Complete validation suite (1-2 minutes)"
            ;;
    esac
    
    if [ "$VALIDATION_STRICT" = "true" ]; then
        show_status "info" "⚠️ Strict Mode: Warnings will be treated as errors"
    fi
    
    # Run unified validation with Clean Architecture
    if validate_deployment_environment_unified; then
        next_steps="📋 NEXT STEPS:
   1. ✅ Environment validated! Ready for deployment
   2. Run: apple-deploy deploy [your parameters]
   3. Or check specific areas:
      • Privacy: apple-deploy validate_privacy scheme=\"$SCHEME\"
      • Certificates: apple-deploy setup_certificates team_id=\"$TEAM_ID\"
      • Build: apple-deploy verify_build scheme=\"$SCHEME\""
        show_result_summary "true" "🎉 VALIDATION SUCCESSFUL - Environment ready for deployment!" "$next_steps"
        exit 0
    else
        show_status "info" "💡 TIP: Address the issues above, then re-run validation before deployment"
        exit 1
    fi
fi

# Handle standalone build verification command
if [ "$LANE" = "verify_build" ]; then
    show_header "STANDALONE BUILD VERIFICATION" "🔍"
    show_status "info" "This will verify the integrity, structure, and quality of your built IPA"
    show_status "info" "No deployment will be performed - this is for quality assurance only."
    
    # Parse parameters for build verification
    shift # Remove the lane parameter
    ipa_path=""
    expected_version=""
    expected_build=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            ipa_path=*)
                ipa_path="${1#*=}"
                shift
                ;;
            expected_version=*)
                expected_version="${1#*=}"
                shift
                ;;
            expected_build=*)
                expected_build="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Run build verification
    if verify_build_integrity "$ipa_path" "$expected_version" "$expected_build"; then
        next_steps="📋 BUILD READY FOR DEPLOYMENT:
   ✅ IPA integrity verified
   ✅ Structure and signing validated
   ✅ Performance checks passed

📋 NEXT STEPS:
   1. Deploy to TestFlight: ./scripts/deploy.sh build_and_upload ...
   2. Manual TestFlight check: ./scripts/deploy.sh check_testflight_status ..."
        show_result_summary "true" "BUILD VERIFICATION SUCCESSFUL - Your IPA is ready for deployment!" "$next_steps"
        exit 0
    else
        show_status "info" "💡 TIP: Address the warnings above for optimal app quality"
        show_status "info" "Build can still be deployed, but review warnings for best practices"
        exit 1
    fi
fi

# Handle standalone privacy validation command
if [ "$LANE" = "validate_privacy" ]; then
    show_header "STANDALONE PRIVACY VALIDATION" "🔒"
    show_status "info" "This will validate privacy usage descriptions in your Info.plist file"
    show_status "info" "Prevents TestFlight upload failures due to missing purpose strings (ITMS-90683)"
    
    # Parse parameters for privacy validation
    shift # Remove the lane parameter
    info_plist_path=""
    strict_mode="false"
    scheme=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            info_plist_path=*)
                info_plist_path="${1#*=}"
                shift
                ;;
            strict_mode=*)
                strict_mode="${1#*=}"
                shift
                ;;
            scheme=*)
                scheme="${1#*=}"
                SCHEME="$scheme"
                shift
                ;;
            app_identifier=*)
                APP_IDENTIFIER="${1#*=}"
                shift
                ;;
            privacy_validation=*)
                PRIVACY_VALIDATION="${1#*=}"
                shift
                ;;
            *)
                log_warning "Unknown parameter: $1"
                shift
                ;;
        esac
    done
    
    # Set default privacy validation mode
    if [ -z "$PRIVACY_VALIDATION" ]; then
        PRIVACY_VALIDATION="strict"
    fi
    
    # Auto-detect Info.plist if not provided
    if [ -z "$info_plist_path" ] && [ -n "$scheme" ]; then
        possible_paths=(
            "./$scheme/Info.plist"
            "./$scheme/$scheme-Info.plist"
            "./Sources/$scheme/Info.plist"
            "./Info.plist"
        )
        
        for path in "${possible_paths[@]}"; do
            if [ -f "$path" ]; then
                info_plist_path="$path"
                log_info "📱 Auto-detected Info.plist: $info_plist_path"
                break
            fi
        done
    fi
    
    if [ -z "$info_plist_path" ]; then
        # Try common fallback locations
        for path in "./Info.plist" "./*/Info.plist"; do
            if [ -f "$path" ]; then
                info_plist_path="$path"
                log_info "📱 Found Info.plist: $info_plist_path"
                break
            fi
        done
    fi
    
    if [ -z "$info_plist_path" ] || [ ! -f "$info_plist_path" ]; then
        log_error "❌ Info.plist file not found"
        log_info "💡 Specify path: validate_privacy info_plist_path=\"./MyApp/Info.plist\""
        log_info "💡 Or run from your iOS project directory"
        exit 1
    fi
    
    # Execute privacy validation
    log_info "🔒 Validating privacy usage descriptions..."
    if validate_privacy_usage_descriptions "$info_plist_path" "$strict_mode"; then
        next_steps="📋 NEXT STEPS:
   1. Your app is ready for TestFlight upload
   2. Deploy: apple-deploy deploy ...
   3. Or continue with normal development workflow"
        show_result_summary "true" "PRIVACY VALIDATION SUCCESSFUL - No TestFlight upload issues detected!" "$next_steps"
        exit 0
    else
        log_error "💡 TIP: Fix the privacy issues above to prevent TestFlight upload failures"
        log_info "📖 Privacy Guide: https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/requesting_access_to_protected_resources"
        exit 1
    fi
fi

# Parse named parameters (e.g., app_identifier="com.example.app")
shift # Remove the lane parameter
while [[ $# -gt 0 ]]; do
    case $1 in
        app_identifier=*)
            APP_IDENTIFIER="${1#*=}"
            shift
            ;;
        apple_id=*)
            APPLE_ID="${1#*=}"
            shift
            ;;
        team_id=*)
            TEAM_ID="${1#*=}"
            shift
            ;;
        api_key_id=*)
            API_KEY_ID="${1#*=}"
            shift
            ;;
        api_issuer_id=*)
            API_ISSUER_ID="${1#*=}"
            shift
            ;;
        api_key_path=*)
            API_KEY_PATH="${1#*=}"
            shift
            ;;
        app_name=*)
            APP_NAME="${1#*=}"
            shift
            ;;
        scheme=*)
            SCHEME="${1#*=}"
            shift
            ;;
        configuration=*)
            CONFIGURATION="${1#*=}"
            shift
            ;;
        p12_password=*)
            P12_PASSWORD="${1#*=}"
            shift
            ;;
        version_bump=*)
            VERSION_BUMP="${1#*=}"
            shift
            ;;
        testflight_enhanced=*)
            TESTFLIGHT_ENHANCED="${1#*=}"
            shift
            ;;
        privacy_validation=*)
            PRIVACY_VALIDATION="${1#*=}"
            shift
            ;;
        certificates_dir=*)
            CERT_DIR="${1#*=}"
            shift
            ;;
        profiles_dir=*)
            PROFILES_DIR="${1#*=}"
            shift
            ;;
        app_dir=*)
            APP_DIR="${1#*=}"
            shift
            ;;
        apple_info_dir=*)
            APPLE_INFO_BASE_DIR="${1#*=}"
            shift
            ;;
        scripts_dir=*)
            SCRIPTS_DIR="${1#*=}"
            shift
            ;;
        *)
            echo "❌ Unknown parameter: $1"
            echo "Available parameters:"
            echo "  app_identifier=\"com.example.app\""
            echo "  apple_id=\"your@email.com\""
            echo "  team_id=\"YOUR_TEAM_ID\""
            echo "  api_key_id=\"YOUR_KEY_ID\""
            echo "  api_issuer_id=\"your-issuer-id\""
            echo "  api_key_path=\"AuthKey_XXXXX.p8\""
            echo "  app_name=\"Your App Name\""
            echo "  scheme=\"YourScheme\""
            echo "  configuration=\"Release\""
            echo "  p12_password=\"YourPassword\""
            echo "  version_bump=\"major|minor|patch\""
            echo "  testflight_enhanced=\"true|false\""
            echo "  privacy_validation=\"strict|warn|skip\""
            echo "  app_dir=\"./my_ios_app\""
            echo "  apple_info_dir=\"/shared/ios-teams\"  # Apple info base directory (REQUIRED)"
            echo "  api_key_path=\"AuthKey_XXXXX.p8\""
            echo "  certificates_dir=\"./certificates\""
            echo "  profiles_dir=\"./profiles\""
            exit 1
            ;;
    esac
done

# ===================================================================
# MULTI-TEAM VALIDATION AND DIRECTORY RESOLUTION (v1.6)
# ===================================================================

validate_app_directory() {
    local current_dir=$(pwd)
    
    # Check for Xcode project or workspace
    local xcodeproj_count=$(find . -maxdepth 1 -name "*.xcodeproj" | wc -l)
    local xcworkspace_count=$(find . -maxdepth 1 -name "*.xcworkspace" | wc -l)
    
    if [ $xcodeproj_count -eq 0 ] && [ $xcworkspace_count -eq 0 ]; then
        show_error_with_resolution "E001" "No Xcode project or workspace found" "$current_dir"
        exit 1
    fi
    
    if [ $xcodeproj_count -gt 1 ] || [ $xcworkspace_count -gt 1 ]; then
        echo "⚠️  Warning: Multiple Xcode projects/workspaces found:"
        find . -maxdepth 1 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \)
        echo "💡 Make sure you're in the correct app directory"
    fi
    
    # Set app directory to current directory
    APP_DIR="$(pwd)"
    echo "✅ App directory: $APP_DIR"
}

resolve_apple_info_paths() {
    local team_id="$1"
    local custom_apple_info_dir="$2"  # MANDATORY parameter
    
    # Validate team_id
    if [ -z "$team_id" ]; then
        show_error_with_resolution "E002" "Missing required team_id parameter" ""
        exit 1
    fi
    
    # Validate apple_info_dir (now mandatory)
    if [ -z "$custom_apple_info_dir" ]; then
        show_error_with_resolution "E003" "Missing required apple_info_dir parameter" ""
        exit 1
    fi
    
    # Validate absolute path
    if [[ "$custom_apple_info_dir" != /* ]]; then
        show_error_with_resolution "E003" "Invalid apple_info_dir path (must be absolute)" "$custom_apple_info_dir"
        exit 1
    fi
    
    # Use the mandatory absolute path
    APPLE_INFO_BASE_DIR="$custom_apple_info_dir"
    echo "📁 Using apple_info directory: $APPLE_INFO_BASE_DIR"
    
    # Set team-specific paths
    TEAM_APPLE_INFO_DIR="$APPLE_INFO_BASE_DIR/$team_id"
    CERT_DIR="$TEAM_APPLE_INFO_DIR/certificates"
    PROFILES_DIR="$TEAM_APPLE_INFO_DIR/profiles"
    
    # Validate team directory exists
    if [ ! -d "$TEAM_APPLE_INFO_DIR" ]; then
        echo "❌ Error: Team directory not found: $TEAM_APPLE_INFO_DIR"
        echo "💡 Create team directory structure:"
        echo "   mkdir -p \"$TEAM_APPLE_INFO_DIR\"/{certificates,profiles}"
        echo "   # Then place your AuthKey_*.p8, certificates, and profiles"
        exit 1
    fi
    
    # Validate subdirectories
    validate_team_subdirectories
    
    echo "✅ Team directory: $TEAM_APPLE_INFO_DIR"
}

validate_team_subdirectories() {
    if [ ! -d "$CERT_DIR" ]; then
        echo "❌ Error: certificates directory not found: $CERT_DIR"
        echo "💡 Create: mkdir -p \"$CERT_DIR\""
        exit 1
    fi
    
    if [ ! -d "$PROFILES_DIR" ]; then
        echo "❌ Error: profiles directory not found: $PROFILES_DIR" 
        echo "💡 Create: mkdir -p \"$PROFILES_DIR\""
        exit 1
    fi
}

# Configuration - Multi-team structure (v1.6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_ROOT/scripts}"

# Validate app directory and resolve team-based paths
validate_app_directory
resolve_apple_info_paths "$TEAM_ID" "$APPLE_INFO_BASE_DIR"

# Auto-detect API key if not specified (consistent with validation command)
if [ -z "$API_KEY_PATH" ] && [ -n "$TEAM_APPLE_INFO_DIR" ]; then
    # Find all API key files
    api_key_files=$(find "$TEAM_APPLE_INFO_DIR" -name "AuthKey_*.p8" | sort)
    api_key_count=$(echo "$api_key_files" | wc -l | tr -d ' ')
    
    if [ -n "$api_key_files" ] && [ "$api_key_count" -gt 0 ]; then
        if [ "$api_key_count" -eq 1 ]; then
            # Single API key found - use it
            API_KEY_PATH="$api_key_files"
            echo "🔍 Auto-detected API key: $(basename "$API_KEY_PATH")"
            
            # Auto-extract key ID from filename if not provided
            if [ -z "$API_KEY_ID" ]; then
                API_KEY_ID=$(basename "$API_KEY_PATH" | sed 's/AuthKey_\([^.]*\)\.p8/\1/')
                echo "🔍 Auto-extracted API key ID: $API_KEY_ID"
            fi
        else
            # Multiple API keys found - show options and use most recent
            echo "⚠️  Multiple API keys found in $TEAM_APPLE_INFO_DIR:"
            echo "$api_key_files" | while read -r key_file; do
                key_name=$(basename "$key_file")
                key_id=$(echo "$key_name" | sed 's/AuthKey_\([^.]*\)\.p8/\1/')
                key_date=$(stat -f "%Sm" "$key_file" 2>/dev/null || stat -c "%y" "$key_file" 2>/dev/null | cut -d' ' -f1)
                echo "   • $key_name (ID: $key_id, Modified: $key_date)"
            done
            
            # Use the most recently modified API key as default
            API_KEY_PATH=$(echo "$api_key_files" | xargs ls -t | head -n1)
            echo ""
            echo "🔍 Auto-selected most recent API key: $(basename "$API_KEY_PATH")"
            echo "💡 To use a specific API key, add: api_key_path=\"$(basename "$API_KEY_PATH")\""
            
            # Auto-extract key ID from filename if not provided
            if [ -z "$API_KEY_ID" ]; then
                API_KEY_ID=$(basename "$API_KEY_PATH" | sed 's/AuthKey_\([^.]*\)\.p8/\1/')
                echo "🔍 Auto-extracted API key ID: $API_KEY_ID"
            fi
        fi
    else
        echo "⚠️  No API key found in $TEAM_APPLE_INFO_DIR"
        echo "💡 Place your AuthKey_*.p8 file in this directory or specify api_key_path parameter"
    fi
fi

# Team-specific configuration file path (in main team directory, not certificates subdirectory)
APPLE_INFO_CONFIG="$TEAM_APPLE_INFO_DIR/config.env"

echo "🚀 iOS Publishing Automation Platform - Multi-Team TestFlight Deployment (v1.6)"
echo "==============================================================================="
echo "Lane: $LANE"
echo ""
echo "📁 Multi-Team Directory Configuration:"
echo "   - App Directory: $APP_DIR"
echo "   - Apple Info Base: $APPLE_INFO_BASE_DIR"
echo "   - Team Directory: $TEAM_APPLE_INFO_DIR"
echo "   - Team ID: $TEAM_ID"
echo "   - Certificates Directory: $CERT_DIR"
echo "   - Profiles Directory: $PROFILES_DIR"
echo "   - Scripts Directory: $SCRIPTS_DIR"

# API Key debugging will be shown after path resolution

# Team directory structure is validated above - no creation here
# Users must manually create team directories before deployment

# Make paths absolute if they're relative
if [[ "$PROJECT_ROOT" != /* ]]; then
    PROJECT_ROOT="$PWD/$PROJECT_ROOT"
fi
if [[ "$APP_DIR" != /* ]]; then
    APP_DIR="$PWD/$APP_DIR"
fi
if [[ "$SCRIPTS_DIR" != /* ]]; then
    SCRIPTS_DIR="$PWD/$SCRIPTS_DIR"
fi
if [[ "$CERT_DIR" != /* ]]; then
    CERT_DIR="$PWD/$CERT_DIR"
fi
if [[ "$PROFILES_DIR" != /* ]]; then
    PROFILES_DIR="$PWD/$PROFILES_DIR"
fi

# Team-based API key path resolution (v1.6)
if [[ -n "$API_KEY_PATH" ]]; then
    if [[ "$API_KEY_PATH" != /* ]]; then
        # If it's just a filename or relative path, check team directory first
        if [[ "$API_KEY_PATH" != */* ]]; then
            # It's just a filename, check team-specific locations
            if [ -f "$TEAM_APPLE_INFO_DIR/$API_KEY_PATH" ]; then
                API_KEY_PATH="$(cd "$(dirname "$TEAM_APPLE_INFO_DIR/$API_KEY_PATH")" && pwd)/$(basename "$API_KEY_PATH")"
                echo "🏢 Using API key from team directory: $API_KEY_PATH"
            # Fallback: check team certificates directory  
            elif [ -f "$CERT_DIR/$API_KEY_PATH" ]; then
                API_KEY_PATH="$(cd "$(dirname "$CERT_DIR/$API_KEY_PATH")" && pwd)/$(basename "$API_KEY_PATH")"
                echo "🏢 Using API key from team certificates: $API_KEY_PATH"
            else
                # Default to team directory for new files - make it absolute
                API_KEY_PATH="$(cd "$(dirname "$TEAM_APPLE_INFO_DIR")" && pwd)/$(basename "$TEAM_APPLE_INFO_DIR")/$API_KEY_PATH"
                echo "🏢 API key path defaulted to team directory: $API_KEY_PATH"
            fi
        else
            # It's a relative path, make it absolute
            API_KEY_PATH="$PWD/$API_KEY_PATH"
        fi
    fi
fi

# Store command line parameters before loading config.env
CMD_SCHEME="${SCHEME}"
CMD_API_KEY_ID="${API_KEY_ID}"
CMD_APP_IDENTIFIER="${APP_IDENTIFIER}"
CMD_APP_NAME="${APP_NAME}"
CMD_APPLE_ID="${APPLE_ID}"
CMD_TEAM_ID="${TEAM_ID}"
CMD_CONFIGURATION="${CONFIGURATION}"
CMD_API_KEY_PATH="${API_KEY_PATH}"

# Load config.env as reference/fallback (optional)
# Priority: apple_info/config.env > certificates/config.env  
if [ -n "$APPLE_INFO_CONFIG" ] && [ -f "$APPLE_INFO_CONFIG" ]; then
    CONFIG_FILE="$APPLE_INFO_CONFIG"
    echo "📋 Loading apple_info/config.env as reference..."
    source "$CONFIG_FILE"
elif [ -f "$CERT_DIR/config.env" ]; then
    CONFIG_FILE="$CERT_DIR/config.env"
    echo "📋 Loading certificates/config.env as reference..."
    source "$CONFIG_FILE"
else
    CONFIG_FILE="$CERT_DIR/config.env"  # Default for new file creation
fi

# Primary Configuration - command line parameters take precedence over config.env
SCHEME="${CMD_SCHEME:-${SCHEME}}"
API_KEY_ID="${CMD_API_KEY_ID:-${API_KEY_ID}}"
API_ISSUER_ID="${API_ISSUER_ID}" 
APP_IDENTIFIER="${CMD_APP_IDENTIFIER:-${APP_IDENTIFIER}}"
APP_NAME="${CMD_APP_NAME:-${APP_NAME}}"
APPLE_ID="${CMD_APPLE_ID:-${APPLE_ID}}"
TEAM_ID="${CMD_TEAM_ID:-${TEAM_ID}}"
CONFIGURATION="${CMD_CONFIGURATION:-${CONFIGURATION:-Release}}"
API_KEY_PATH="${CMD_API_KEY_PATH:-${API_KEY_PATH}}"

# Enhanced API Key Debugging (after path resolution)
if [ -n "$API_KEY_PATH" ]; then
    echo ""
    echo "🔑 API Key Configuration (Final):"
    echo "   - API Key Path: $API_KEY_PATH"
    if [ -f "$API_KEY_PATH" ]; then
        echo "   - API Key File: ✅ EXISTS"
        echo "   - File Size: $(ls -lh "$API_KEY_PATH" | awk '{print $5}')"
        echo "   - File Permissions: $(ls -l "$API_KEY_PATH" | awk '{print $1}')"
    else
        echo "   - API Key File: ❌ NOT FOUND"
        echo "   - Expected Location: $API_KEY_PATH"
        echo "   - Please check if the file exists at this path"
    fi
fi

# Generate default P12 password if not provided
if [ -z "$P12_PASSWORD" ]; then
    # Generate a secure random password using app identifier and timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    APP_SHORT=$(echo "$APP_IDENTIFIER" | sed 's/com\.//' | sed 's/\.//g')
    P12_PASSWORD="${APP_SHORT}_${TIMESTAMP}!"
    echo "🔐 Generated default P12 password: [PROTECTED]"
else
    echo "🔐 Using provided P12 password: [PROTECTED]"
fi

# Set default version_bump to patch if not provided
if [ -z "$VERSION_BUMP" ]; then
    VERSION_BUMP="patch"
    echo "📱 Using default version_bump: $VERSION_BUMP"
fi

# Set default testflight_enhanced to false if not provided
if [ -z "$TESTFLIGHT_ENHANCED" ]; then
    TESTFLIGHT_ENHANCED="false"
    echo "📱 Using default testflight_enhanced: $TESTFLIGHT_ENHANCED"
elif [[ "$TESTFLIGHT_ENHANCED" == "true" ]]; then
    echo "🚀 TestFlight Enhanced Mode: ENABLED (extended confirmation & enhanced logging)"
elif [[ "$TESTFLIGHT_ENHANCED" == "false" ]]; then
    echo "📱 TestFlight Standard Mode: Basic upload confirmation"
else
    echo "❌ Invalid testflight_enhanced value: $TESTFLIGHT_ENHANCED (must be 'true' or 'false')"
    exit 1
fi

# Function to create comprehensive config.env file
create_comprehensive_config_env() {
    local config_file="$1"
    
    echo "🆕 Creating comprehensive config.env file at: $config_file"
    
    cat > "$config_file" << EOF
# iOS Publishing Automation Configuration
# Team: $TEAM_ID ($APPLE_ID)
# Generated: $(date +%Y-%m-%d)

# Team Configuration
TEAM_ID=$TEAM_ID
TEAM_NAME="$(echo "$APPLE_ID" | cut -d'@' -f1)"
APPLE_ID=$APPLE_ID

# API Configuration
API_KEY_ID=$API_KEY_ID
API_ISSUER_ID=$API_ISSUER_ID
API_KEY_PATH=$(basename "$API_KEY_PATH")

# App Configuration
APP_IDENTIFIER=$APP_IDENTIFIER
APP_NAME="$APP_NAME"
SCHEME=$SCHEME

# Security Configuration
P12_PASSWORD="$P12_PASSWORD"

# Last Deployment
LAST_DEPLOYMENT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LAST_DEPLOYMENT_VERSION=auto-incremented
LAST_DEPLOYMENT_BUILD=auto-incremented

# Status
STATUS=PRODUCTION_READY
TESTFLIGHT_STATUS=CONFIGURED
EOF
    
    echo "✅ Created comprehensive config.env file"
}

# Function to update config.env with the correct P12 password
update_config_env_password() {
    local config_file="$TEAM_APPLE_INFO_DIR/config.env"
    
    if [ -f "$config_file" ]; then
        echo "📝 Updating config.env with correct P12 password..."
        
        # Update or add P12_PASSWORD
        if grep -q "^P12_PASSWORD=" "$config_file"; then
            # Update existing entry
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/^P12_PASSWORD=.*/P12_PASSWORD=\"$P12_PASSWORD\"/" "$config_file"
            else
                sed -i "s/^P12_PASSWORD=.*/P12_PASSWORD=\"$P12_PASSWORD\"/" "$config_file"
            fi
        else
            # Add new entry
            echo "" >> "$config_file"
            echo "# Updated P12 password (auto-generated on $(date))" >> "$config_file"
            echo "P12_PASSWORD=\"$P12_PASSWORD\"" >> "$config_file"
        fi
        echo "✅ Updated config.env with P12 password"
    else
        echo "📝 Creating new config.env file..."
        create_comprehensive_config_env "$config_file"
    fi
}

# Validate required configuration
if [ -z "$APP_IDENTIFIER" ] || [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$API_KEY_ID" ] || [ -z "$API_ISSUER_ID" ] || [ -z "$API_KEY_PATH" ]; then
    echo "❌ ERROR: Missing required configuration!"
    echo "Please set these environment variables or configure config.env:"
    echo "  - APP_IDENTIFIER (e.g., com.yourcompany.yourapp)"
    echo "  - APPLE_ID (e.g., your@email.com)"
    echo "  - TEAM_ID (e.g., ABC123DEF4)"
    echo "  - API_KEY_ID (e.g., XYZ789ABC1)"
    echo "  - API_ISSUER_ID (e.g., 12345678-1234-1234-1234-123456789012)"
    echo "  - API_KEY_PATH (e.g., AuthKey_XYZ789ABC1.p8)"
    echo ""
    echo "See config_example.txt for reference configuration."
    exit 1
fi

# Step 1: Cleanup - Remove existing fastlane files from app directory
STEP1_START_TIME=$(date +%s)
show_progress_header 1 "Cleanup and Preparation" "10-15s"

log_info "🧹 Cleaning up existing fastlane files..."
log_debug "App directory: $APP_DIR"

if [ -d "$APP_DIR/fastlane" ]; then
    log_debug "Removing existing fastlane directory: $APP_DIR/fastlane"
    rm -rf "$APP_DIR/fastlane"
    log_success "Removed existing app/fastlane directory"
else
    log_debug "No existing fastlane directory found"
fi

if [ -f "$APP_DIR/fastlane_config.rb" ]; then
    log_debug "Removing existing fastlane_config.rb: $APP_DIR/fastlane_config.rb"
    rm -f "$APP_DIR/fastlane_config.rb"
    log_success "Removed existing app/fastlane_config.rb"
else
    log_debug "No existing fastlane_config.rb found"
fi

STEP1_END_TIME=$(date +%s)
STEP1_DURATION=$((STEP1_END_TIME - STEP1_START_TIME))
show_step_completion 1 "Cleanup and Preparation" "true" "$STEP1_DURATION"

# Step 2: Copy fresh fastlane files from scripts directory
STEP2_START_TIME=$(date +%s)
show_progress_header 2 "Setup FastLane Scripts" "5-10s"

log_info "📋 Copying fresh fastlane files..."
log_debug "Source directory: $SCRIPTS_DIR"
log_debug "Target directory: $APP_DIR"

log_debug "Copying fastlane directory: $SCRIPTS_DIR/fastlane -> $APP_DIR/"
cp -r "$SCRIPTS_DIR/fastlane" "$APP_DIR/"
log_success "Copied scripts/fastlane/ to app/fastlane/"

if [ -f "$SCRIPTS_DIR/fastlane_config.rb" ]; then
    log_debug "Copying fastlane_config.rb: $SCRIPTS_DIR/fastlane_config.rb -> $APP_DIR/"
    cp "$SCRIPTS_DIR/fastlane_config.rb" "$APP_DIR/"
    log_success "Copied scripts/fastlane_config.rb to app/"
else
    log_debug "No fastlane_config.rb found in scripts directory"
fi

STEP2_END_TIME=$(date +%s)
STEP2_DURATION=$((STEP2_END_TIME - STEP2_START_TIME))
show_step_completion 2 "Setup FastLane Scripts" "true" "$STEP2_DURATION"

# Step 2b: Privacy Validation
STEP25_START_TIME=$(date +%s)
show_progress_header "2b" "Privacy Validation" "10-20s"

# Set default privacy validation mode if not specified
if [ -z "$PRIVACY_VALIDATION" ]; then
    PRIVACY_VALIDATION="strict"
fi

log_info "🔒 Checking privacy usage descriptions compliance..."
log_debug "Privacy validation mode: $PRIVACY_VALIDATION"

# Find Info.plist for privacy validation
INFO_PLIST_PATH=""
if [ -n "$SCHEME" ]; then
    # Try scheme-based paths first
    POSSIBLE_INFO_PLISTS=(
        "./$SCHEME/Info.plist"
        "./$SCHEME/$SCHEME-Info.plist"
        "./Sources/$SCHEME/Info.plist"
        "./Info.plist"
    )
else
    # Fallback paths
    POSSIBLE_INFO_PLISTS=(
        "./Info.plist"
        "./*/Info.plist"
    )
fi

for plist_path in "${POSSIBLE_INFO_PLISTS[@]}"; do
    if [ -f "$plist_path" ]; then
        INFO_PLIST_PATH="$plist_path"
        log_debug "Found Info.plist: $INFO_PLIST_PATH"
        break
    fi
done

# Execute privacy validation
if validate_privacy_usage_descriptions "$INFO_PLIST_PATH"; then
    log_success "✅ Privacy validation passed"
    PRIVACY_VALIDATION_RESULT="passed"
else
    log_error "❌ Privacy validation failed"
    PRIVACY_VALIDATION_RESULT="failed"
    
    # Handle validation failure based on mode
    if [ "$PRIVACY_VALIDATION" = "strict" ]; then
        STEP25_END_TIME=$(date +%s)
        STEP25_DURATION=$((STEP25_END_TIME - STEP25_START_TIME))
        show_step_completion "2b" "Privacy Validation" "false" "$STEP25_DURATION"
        log_error "🛑 Deployment stopped due to privacy validation failure"
        log_info "💡 Fix privacy issues and retry, or use privacy_validation=\"warn\" to continue"
        exit 1
    fi
fi

STEP25_END_TIME=$(date +%s)
STEP25_DURATION=$((STEP25_END_TIME - STEP25_START_TIME))
show_step_completion "2b" "Privacy Validation" "true" "$STEP25_DURATION"

# Step 3: Verify Xcode project exists
STEP3_START_TIME=$(date +%s)
show_progress_header 3 "Xcode Project Verification" "5s"

log_info "📱 Verifying Xcode project..."
cd "$APP_DIR"
if ls -d *.xcodeproj 1> /dev/null 2>&1; then
    PROJECT=$(ls -d *.xcodeproj | head -1)
    log_success "Found Xcode project: $PROJECT"
else
    STEP3_END_TIME=$(date +%s)
    STEP3_DURATION=$((STEP3_END_TIME - STEP3_START_TIME))
    show_step_completion 3 "Xcode Project Verification" "false" "$STEP3_DURATION"
    show_error_with_resolution "E001" "No Xcode project found in app directory" "$(pwd)"
    exit 1
fi

STEP3_END_TIME=$(date +%s)
STEP3_DURATION=$((STEP3_END_TIME - STEP3_START_TIME))
show_step_completion 3 "Xcode Project Verification" "true" "$STEP3_DURATION"

# Step 4: Smart Version Management
STEP4_START_TIME=$(date +%s)
show_progress_header 4 "Smart Version Management" "15-30s"

log_info "📈 Processing version management..."
if [ "$LANE" = "build_and_upload" ]; then
    # Ensure we're in the correct app directory
    echo "📁 Ensuring we're in the correct app directory: $APP_DIR"
    cd "$APP_DIR"
    echo "📁 Current directory after cd: $(pwd)"
    
    # Handle marketing version bump if requested
    if [ -n "$VERSION_BUMP" ]; then
        echo "🎯 Marketing version increment requested: $VERSION_BUMP"
        
        echo "📱 Local versioning mode: $VERSION_BUMP"
        echo "🔧 Will increment version locally based on project file"
        
        # Get current marketing version from project.pbxproj
        PROJECT_FILE="$PROJECT/project.pbxproj"
        CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJECT_FILE" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')
        echo "📱 Current marketing version: $CURRENT_VERSION"
        
        # Validate version bump parameter
        if [[ "$VERSION_BUMP" =~ ^(major|minor|patch)$ ]]; then
            echo "✅ Valid version_bump: $VERSION_BUMP"
            
            # Parse current version into components
            IFS='.' read -r -a version_parts <<< "$CURRENT_VERSION"
            major=${version_parts[0]:-1}
            minor=${version_parts[1]:-0}
            patch=${version_parts[2]:-0}
            
            # Handle different increment types
            case "$VERSION_BUMP" in
                major)
                    major=$((major + 1))
                    minor=0
                    patch=0
                    NEW_VERSION="$major.$minor.$patch"
                    echo "📈 Updating marketing version: $CURRENT_VERSION → $NEW_VERSION"
                    ;;
                minor)
                    minor=$((minor + 1))
                    patch=0
                    NEW_VERSION="$major.$minor.$patch"
                    echo "📈 Updating marketing version: $CURRENT_VERSION → $NEW_VERSION"
                    ;;
                patch)
                    patch=$((patch + 1))
                    NEW_VERSION="$major.$minor.$patch"
                    echo "📈 Updating marketing version: $CURRENT_VERSION → $NEW_VERSION"
                    ;;
            esac
            
            # Update marketing version directly in project.pbxproj
            sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $NEW_VERSION/g" "$PROJECT_FILE"
            
            # Verify the change
            UPDATED_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJECT_FILE" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')
            echo "✅ Marketing version updated to: $UPDATED_VERSION"
            echo "📱 Versioning mode: Local ($VERSION_BUMP increment)"
            
            # Final versioning summary
            echo ""
            echo "📋 Marketing Version Management Summary:"
            echo "   - Original version: $CURRENT_VERSION"
            echo "   - Final version: $UPDATED_VERSION"
            
            # Capture final version for deployment summary
            DEPLOYMENT_VERSION="$UPDATED_VERSION"
            echo "   - Increment mode: $VERSION_BUMP"
            echo "   - Management type: Local"
        else
            echo "❌ Invalid version_bump value: $VERSION_BUMP"
            echo "Valid values are: major, minor, patch"
            echo "Note: TestFlight conflict resolution is automatic for all version_bump types"
            exit 1
        fi
    fi
    
    echo "🔍 Getting current build number from project..."
    
    # Simple local build number management (no TestFlight API dependency)
    echo "📱 Using local build number increment (simplified architecture)"
    echo "📁 Current working directory: $(pwd)"
    echo "📁 Contents of current directory:"
    ls -la .
    
    # Find the .xcodeproj directory
    XCODEPROJ_DIR=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -1)
    if [ -n "$XCODEPROJ_DIR" ]; then
        PROJECT_FILE="$XCODEPROJ_DIR/project.pbxproj"
        echo "📋 Found .xcodeproj directory: $XCODEPROJ_DIR"
        echo "📋 Project file path: $PROJECT_FILE"
    else
        echo "❌ Error: No .xcodeproj directory found in $(pwd)"
        echo "🔍 Looking for .xcodeproj files recursively:"
        find . -name "*.xcodeproj" -type d
        exit 1
    fi
    
    if [ -f "$PROJECT_FILE" ]; then
        CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/' | tr -d ' ' | head -1)
        echo "📱 Current project build: $CURRENT_BUILD"
    else
        echo "❌ Error: Project file not found at $PROJECT_FILE"
        exit 1
    fi
    
    # Enhanced build number increment with TestFlight conflict resolution
    echo "🔍 Checking for TestFlight build conflicts..."
    
    # Function to check if a build number already exists in TestFlight
    check_testflight_build_exists() {
        local version="$1"
        local build="$2"
        
        # Use xcrun altool to check existing builds (requires API credentials)
        if [[ -n "$API_KEY_ID" && -n "$API_ISSUER_ID" && -n "$API_KEY_PATH" ]]; then
            echo "🔍 Checking TestFlight for version $version build $build..."
            
            # Create temporary API key location for altool
            temp_private_keys_dir="$HOME/.appstoreconnect/private_keys"
            mkdir -p "$temp_private_keys_dir"
            temp_api_key_path="$temp_private_keys_dir/$(basename "$API_KEY_PATH")"
            cp "$API_KEY_PATH" "$temp_api_key_path" 2>/dev/null || true
            
            # Query existing builds (redirect stderr to suppress verbose output)
            existing_builds=$(xcrun altool --list-builds \
                --app-identifier "$APP_IDENTIFIER" \
                --apiKey "$API_KEY_ID" \
                --apiIssuer "$API_ISSUER_ID" 2>/dev/null | grep -E "Version: $version.*Build: $build" || true)
            
            # Cleanup temporary API key
            rm -f "$temp_api_key_path" 2>/dev/null || true
            
            if [[ -n "$existing_builds" ]]; then
                echo "⚠️  Build $build for version $version already exists in TestFlight"
                return 0  # Build exists
            else
                echo "✅ Build $build for version $version is available"
                return 1  # Build doesn't exist
            fi
        else
            echo "⚠️  TestFlight conflict check skipped (API credentials not available)"
            return 1  # Assume build doesn't exist if we can't check
        fi
    }
    
    # Start with simple local increment
    if [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
        NEW_BUILD=$(($CURRENT_BUILD + 1))
        echo "📋 Initial build number increment: $CURRENT_BUILD → $NEW_BUILD"
    else
        NEW_BUILD=1
        echo "📋 Using default build number: $NEW_BUILD"
    fi
    
    # Check for TestFlight conflicts and auto-increment if needed
    MAX_RETRIES=10  # Prevent infinite loops
    retry_count=0
    current_version="$DEPLOYMENT_VERSION"
    
    if [[ -z "$current_version" ]]; then
        # Fallback to project version if DEPLOYMENT_VERSION not set
        current_version=$(grep -m1 "MARKETING_VERSION = " "$PROJECT_FILE" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')
    fi
    
    echo "🎯 Resolving conflicts for version $current_version..."
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        if check_testflight_build_exists "$current_version" "$NEW_BUILD"; then
            # Build exists, increment and try again
            OLD_BUILD=$NEW_BUILD
            NEW_BUILD=$(($NEW_BUILD + 1))
            echo "🔄 Build $OLD_BUILD exists in TestFlight, trying $NEW_BUILD..."
            retry_count=$(($retry_count + 1))
        else
            # Build doesn't exist, we're good to go
            echo "✅ Build number $NEW_BUILD is available for version $current_version"
            break
        fi
    done
    
    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        echo "⚠️  Reached maximum retry limit ($MAX_RETRIES) for TestFlight conflict resolution"
        echo "💡 Using build number $NEW_BUILD anyway - manual resolution may be needed"
    fi
    
    echo "📈 Setting build number to: $NEW_BUILD"
    
    # Ensure we're in the app directory and can access project files
    if [ ! -f "$PROJECT_FILE" ]; then
        echo "❌ Error: Project file not accessible at $PROJECT_FILE"
        echo "Current directory: $(pwd)"
        echo "App directory should be: $APP_DIR"
        exit 1
    fi
    
    # Check if project uses auto-generated Info.plist (reuse PROJECT_FILE from above)
    USES_GENERATED_INFOPLIST=$(grep -c "GENERATE_INFOPLIST_FILE = YES" "$PROJECT_FILE" || echo "0")
    
    if [ "$USES_GENERATED_INFOPLIST" -gt 0 ]; then
        echo "🔍 Detected GENERATE_INFOPLIST_FILE = YES"
        echo "✅ Using manual project.pbxproj update (agvtool doesn't support auto-generated Info.plist)"
        
        # Backup the project file
        cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
        
        # Update build number directly in project.pbxproj
        sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$PROJECT_FILE"
        
        # Verify the update
        UPDATED_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/' | tr -d ' ' | head -1)
        UPDATED_COUNT=$(grep -c "CURRENT_PROJECT_VERSION = $NEW_BUILD" "$PROJECT_FILE")
        
        if [ "$UPDATED_BUILD" = "$NEW_BUILD" ] && [ "$UPDATED_COUNT" -gt 0 ]; then
            echo "✅ Build number updated to: $NEW_BUILD ($UPDATED_COUNT occurrences)"
            rm "$PROJECT_FILE.backup"  # Clean up backup
        else
            echo "❌ Build number update failed, restoring backup"
            mv "$PROJECT_FILE.backup" "$PROJECT_FILE"
            exit 1
        fi
    else
        echo "🔍 Using traditional Info.plist approach"
        echo "🔧 Running: agvtool new-version -all $NEW_BUILD"
        
        # Use agvtool normally for projects with traditional Info.plist files
        agvtool new-version -all $NEW_BUILD
        
        if [ $? -eq 0 ]; then
            # Verify with agvtool
            UPDATED_BUILD=$(agvtool what-version 2>/dev/null | tail -1 | xargs)
            echo "✅ Build number updated to: $UPDATED_BUILD"
        else
            echo "❌ agvtool failed"
            exit 1
        fi
    fi
    
    # Final verification regardless of method used
    FINAL_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/' | tr -d ' ' | head -1)
    echo "📋 Final verification - Build number in project: $FINAL_BUILD"
    
    if [ "$FINAL_BUILD" = "$NEW_BUILD" ]; then
        echo "✅ Build number successfully set to: $NEW_BUILD"
        # Capture final build number for deployment summary
        DEPLOYMENT_BUILD="$NEW_BUILD"
    else
        echo "❌ Build number verification failed!"
        echo "   Expected: $NEW_BUILD"
        echo "   Found: $FINAL_BUILD"
        exit 1
    fi
    
    STEP4_END_TIME=$(date +%s)
    STEP4_DURATION=$((STEP4_END_TIME - STEP4_START_TIME))
    show_step_completion 4 "Smart Version Management" "true" "$STEP4_DURATION"
else
    log_info "⏭️  Skipping version management for lane: $LANE"
    
    STEP4_END_TIME=$(date +%s)
    STEP4_DURATION=$((STEP4_END_TIME - STEP4_START_TIME))
    show_step_completion 4 "Smart Version Management" "true" "$STEP4_DURATION"
fi

# Step 5: Run fastlane deployment
STEP5_START_TIME=$(date +%s)

# Determine estimated time based on lane
case "$LANE" in
    "build_and_upload")
        show_progress_header 5 "Build and Upload to TestFlight" "3-8 minutes"
        ;;
    "setup_certificates"|"setup_team_certificates")
        show_progress_header 5 "Certificate Setup" "30-60s"
        ;;
    *)
        show_progress_header 5 "FastLane Execution" "30s-5m"
        ;;
esac

# Auto-detect team collaboration mode for certificate setup
if [ "$LANE" = "setup_certificates" ]; then
    # Check if we have existing P12 files (team member) or should create new ones (team lead)
    # Prioritize team collaboration files but fall back to any P12 files
    TEAM_P12_FILES_COUNT=$(find "$CERT_DIR" -name "*_exported.p12" 2>/dev/null | wc -l)
    REGULAR_P12_FILES_COUNT=$(find "$CERT_DIR" -name "*.p12" 2>/dev/null | wc -l)
    
    if [ "$TEAM_P12_FILES_COUNT" -gt 0 ]; then
        P12_FILES_COUNT=$TEAM_P12_FILES_COUNT
        log_info "🤝 Team collaboration detected: Found $P12_FILES_COUNT team P12 files (*_exported.p12)"
    elif [ "$REGULAR_P12_FILES_COUNT" -gt 0 ]; then
        P12_FILES_COUNT=$REGULAR_P12_FILES_COUNT
        log_info "📁 P12 files detected: Found $P12_FILES_COUNT certificate files (*.p12)"
    else
        P12_FILES_COUNT=0
    fi
    
    if [ "$P12_FILES_COUNT" -gt 0 ]; then
        log_info "📥 P12 files will be imported for team collaboration"
        LANE="setup_team_certificates"
    else
        log_info "👤 Solo/Team lead setup: No P12 files found, will create certificates and export for team"
        LANE="setup_team_certificates"
    fi
fi

log_info "🚀 Executing fastlane lane: $LANE..."
echo "Command: fastlane $LANE with parameters..."
echo "📋 Configuration values:"
echo "   - Scheme: $SCHEME"
echo "   - App ID: $APP_IDENTIFIER"
echo "   - API Key Path: $API_KEY_PATH"
echo "   - API Key ID: $API_KEY_ID"
echo "   - Team ID: $TEAM_ID"
echo "   - P12 Password: [PROTECTED]"
echo "   - TestFlight Enhanced: $TESTFLIGHT_ENHANCED"
echo ""
echo "🔧 FastLane Parameters Being Passed:"
echo "   - certificates_dir: $CERT_DIR"
echo "   - profiles_dir: $PROFILES_DIR"
echo ""

# BULLETPROOF APPLE_INFO STRUCTURE ENFORCEMENT
echo "🛡️  BULLETPROOF: Forcing apple_info directory structure..."

# Store current directory
ORIGINAL_PWD="$PWD"

# Change to app directory to make all "../" paths resolve to apple_info structure
cd "$APP_DIR"
echo "📁 Changed working directory to: $APP_DIR"

# Use team-based directory structure from apple_info_dir parameter
CERT_DIR="$TEAM_APPLE_INFO_DIR/certificates"
PROFILES_DIR="$TEAM_APPLE_INFO_DIR/profiles"
echo "🏢 Using team-based directory structure"
echo "   - app_dir: $APP_DIR"
echo "   - team_dir: $TEAM_APPLE_INFO_DIR"
echo "   - certificates_dir: $CERT_DIR"
echo "   - profiles_dir: $PROFILES_DIR"

# Use API key from team directory (already resolved)
FASTLANE_API_KEY_PATH="$API_KEY_PATH"
echo "🔑 FastLane will use API key: $FASTLANE_API_KEY_PATH"

# Verify API key exists
if [ ! -f "$API_KEY_PATH" ]; then
    echo "❌ Error: API key not found at: $API_KEY_PATH"
    exit 1
fi

# BULLETPROOF PATH VALIDATION
echo "🔍 BULLETPROOF VALIDATION: Verifying apple_info structure..."

# Validate that all required directories exist
if [ ! -d "$APPLE_INFO_BASE_DIR" ]; then
    echo "❌ FATAL: apple_info directory not found at: $APPLE_INFO_BASE_DIR"
    exit 1
fi

# Validate team-based directories exist
if [ ! -d "$CERT_DIR" ]; then
    echo "⚠️  Warning: Certificates directory not found at $CERT_DIR"
    echo "📁 Creating certificates directory..."
    mkdir -p "$CERT_DIR"
fi

if [ ! -d "$PROFILES_DIR" ]; then
    echo "⚠️  Warning: Profiles directory not found at $PROFILES_DIR"
    echo "📁 Creating profiles directory..."
    mkdir -p "$PROFILES_DIR"
fi

# Validate API key accessibility
if [ ! -f "$FASTLANE_API_KEY_PATH" ]; then
    echo "❌ FATAL: API key not accessible at: $FASTLANE_API_KEY_PATH"
    exit 1
fi

# Validate Xcode project exists
XCODE_PROJECTS=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -1)
if [ -z "$XCODE_PROJECTS" ]; then
    echo "❌ FATAL: No Xcode project found in app directory"
    echo "   Current directory: $(pwd)"
    echo "   Contents: $(ls -la)"
    exit 1
else
    echo "✅ Found Xcode project: $(basename "$XCODE_PROJECTS")"
fi

echo "✅ BULLETPROOF VALIDATION PASSED"
echo ""
echo "🔍 TEAM-BASED VERIFICATION: FastLane will use these team directories:"
echo "   - certificates_dir → $CERT_DIR"
echo "   - profiles_dir → $PROFILES_DIR"
echo "   - Working directory: $(pwd)"
echo "   - API key path for FastLane: $FASTLANE_API_KEY_PATH"
echo ""


# Set environment variables for fastlane to avoid parameter parsing issues
export FL_APP_IDENTIFIER="$APP_IDENTIFIER"
export FL_APP_NAME="$APP_NAME" 
export FL_APPLE_ID="$APPLE_ID"
export FL_TEAM_ID="$TEAM_ID"
export FL_APPLE_INFO_DIR="$APPLE_INFO_BASE_DIR"
export FL_API_KEY_PATH="$FASTLANE_API_KEY_PATH"
export FL_API_KEY_ID="$API_KEY_ID"
export FL_API_ISSUER_ID="$API_ISSUER_ID"
export FL_SCHEME="$SCHEME"
export FL_CONFIGURATION="$CONFIGURATION"
export FL_PASSWORD="$P12_PASSWORD"
export FL_APP_DIR="$APP_DIR"
export FL_CERTIFICATES_DIR="$CERT_DIR"
export FL_PROFILES_DIR="$PROFILES_DIR"
export FL_TESTFLIGHT_ENHANCED="$TESTFLIGHT_ENHANCED"
export FL_SCRIPTS_DIR="$SCRIPTS_DIR"

# Enhanced pre-execution validation with comprehensive error messaging
log_info "Running enhanced pre-execution validation..."

# Ensure directories exist (create if missing rather than error)
log_debug "Ensuring required directories exist..."
if [ ! -d "$CERT_DIR" ]; then
    log_info "Creating certificates directory: $CERT_DIR"
    mkdir -p "$CERT_DIR"
fi

if [ ! -d "$PROFILES_DIR" ]; then
    log_info "Creating profiles directory: $PROFILES_DIR"
    mkdir -p "$PROFILES_DIR"
fi

# Run comprehensive validation
if ! validate_deployment_environment; then
    echo ""
    log_error "Pre-execution validation failed. Please fix the errors above before continuing."
    exit 1
fi

log_success "Enhanced pre-execution validation passed"

# Clean up backup and temporary files before deployment
log_debug "Performing pre-deployment cleanup..."
cleanup_backup_files "."
cleanup_backup_files "$CERT_DIR"
cleanup_backup_files "$PROFILES_DIR"

# Execute FastLane with comprehensive error handling
log_info "🚀 Starting FastLane execution..."
log_info "⏱️  Start time: $(date '+%H:%M:%S')"
estimate_remaining_time $((CURRENT_STEP - 1))

# Show real-time progress indicator
echo ""
echo "🔄 FastLane is running..."
case "$LANE" in
    "build_and_upload")
        echo "📱 This includes: Certificate setup → Provisioning profiles → Build → Upload"
        echo "⏳ Please wait 3-8 minutes (longer for first build or large apps)"
        ;;
    "setup_certificates"|"setup_team_certificates")
        echo "🔐 This includes: Certificate creation/import → Provisioning profile setup"
        echo "⏳ Please wait 30-60 seconds"
        ;;
esac
echo ""

# Temporarily disable exit on error for custom error handling
set +e

# Capture FastLane output for intelligent error detection
FASTLANE_OUTPUT_FILE="/tmp/fastlane_output_$$"
fastlane "$LANE" 2>&1 | tee "$FASTLANE_OUTPUT_FILE"
FASTLANE_EXIT_CODE=${PIPESTATUS[0]}

# Re-enable exit on error
set -e

STEP5_END_TIME=$(date +%s)
STEP5_DURATION=$((STEP5_END_TIME - STEP5_START_TIME))

# Handle FastLane results with intelligent error detection
if [ $FASTLANE_EXIT_CODE -eq 0 ]; then
    show_step_completion 5 "FastLane Execution" "true" "$STEP5_DURATION"
    log_success "FastLane execution completed successfully!"
    log_info "⏱️  Completed in ${STEP5_DURATION} seconds"
    
    # Run build verification system for quality assurance
    if [ "$LANE" = "build_and_upload" ] || [ "$LANE" = "build_app" ]; then
        echo ""
        log_info "🔍 Running build verification system..."
        
        # Try to determine expected version/build from environment
        expected_version="${FL_VERSION:-unknown}"
        expected_build="${FL_BUILD_NUMBER:-unknown}"
        
        # Call build verification with auto-detection
        if verify_build_integrity "" "$expected_version" "$expected_build"; then
            log_success "✅ Build verification passed - Build quality confirmed!"
        else
            log_warning "⚠️  Build verification found warnings - Review above for details"
            log_info "💡 Build can still be deployed, but review warnings for optimization"
        fi
        echo ""
    fi
    
    # Clean up temporary files
    [ -f "$FASTLANE_OUTPUT_FILE" ] && rm -f "$FASTLANE_OUTPUT_FILE"
else
    show_step_completion 5 "FastLane Execution" "false" "$STEP5_DURATION"
    
    # Detect specific error type from output
    FASTLANE_LOG_CONTENT=""
    if [ -f "$FASTLANE_OUTPUT_FILE" ]; then
        FASTLANE_LOG_CONTENT=$(cat "$FASTLANE_OUTPUT_FILE")
    fi
    
    ERROR_TYPE=$(detect_error_type "$FASTLANE_EXIT_CODE" "$FASTLANE_LOG_CONTENT")
    
    # Show appropriate error message based on detected type
    case "$ERROR_TYPE" in
        "E005")
            show_error_with_resolution "E005" "Certificate or provisioning profile issues detected" "FastLane execution"
            ;;
        "E006")
            show_error_with_resolution "E006" "Network or API connectivity issues detected" "FastLane execution"
            ;;
        "E007")
            show_error_with_resolution "E007" "Build or compilation failure detected" "FastLane execution"
            ;;
        *)
            show_error_with_resolution "E004" "FastLane execution failed" "$FASTLANE_EXIT_CODE"
            ;;
    esac
    
    echo "📋 CURRENT ENVIRONMENT VARIABLES:"
    echo "   - FL_APP_IDENTIFIER: $FL_APP_IDENTIFIER"
    echo "   - FL_TEAM_ID: $FL_TEAM_ID"
    echo "   - FL_API_KEY_PATH: $FL_API_KEY_PATH"
    echo "   - FL_CERTIFICATES_DIR: $FL_CERTIFICATES_DIR"
    echo "   - FL_PROFILES_DIR: $FL_PROFILES_DIR"
    echo "   - Current directory: $(pwd)"
    echo ""
    
    echo "🆘 QUICK RECOVERY OPTIONS:"
    echo "   1. Re-run with debug mode: DEBUG_MODE=true ./scripts/deploy.sh ..."
    echo "   2. Test certificates: ./scripts/deploy.sh setup_certificates ..."
    echo "   3. Check network: ping developer.apple.com"
    echo "   4. Verify API key permissions in App Store Connect"
    echo ""
    
    # Clean up temporary files
    [ -f "$FASTLANE_OUTPUT_FILE" ] && rm -f "$FASTLANE_OUTPUT_FILE"
    
    # Restore original working directory before exit
    cd "$ORIGINAL_PWD"
    
    exit $FASTLANE_EXIT_CODE
fi

# Restore original working directory
cd "$ORIGINAL_PWD"
echo "📁 Restored working directory to: $ORIGINAL_PWD"

# Step 6: Check results and summary
STEP6_START_TIME=$(date +%s)
show_progress_header 6 "Deployment Summary & Cleanup" "10-15s"

log_info "📊 Analyzing deployment results..."

# Check results in apple_info structure
if [ -d "$APP_DIR/apple_info/certificates" ]; then
    log_info "📁 Certificates created in apple_info:"
    ls -la "$APP_DIR"/apple_info/certificates/*.{cer,p12} 2>/dev/null | awk '{print "   - " $9}' || log_info "   - No certificate files found"
fi

if [ -d "$APP_DIR/apple_info/profiles" ]; then
    log_info "📁 Profiles created in apple_info:"
    ls -la "$APP_DIR"/apple_info/profiles/*.mobileprovision 2>/dev/null | awk '{print "   - " $9}' || log_info "   - No profile files found"
fi

if [ -d "./build" ]; then
    log_info "📦 Build artifacts:"
    ls -la ./build/*.ipa 2>/dev/null | awk '{print "   - " $9}' || log_info "   - No IPA files found"
fi

# Update config.env with the P12 password that was used
log_info "📝 Updating configuration files..."
update_config_env_password

STEP6_END_TIME=$(date +%s)
STEP6_DURATION=$((STEP6_END_TIME - STEP6_START_TIME))
show_step_completion 6 "Deployment Summary & Cleanup" "true" "$STEP6_DURATION"

# Final deployment summary
TOTAL_DEPLOYMENT_TIME=$((STEP6_END_TIME - DEPLOYMENT_START_TIME))
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║ 🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉"

# Add version information if available
if [ -n "$DEPLOYMENT_VERSION" ] && [ -n "$DEPLOYMENT_BUILD" ]; then
    echo "║ 📱 Version: $DEPLOYMENT_VERSION (Build $DEPLOYMENT_BUILD)"
elif [ -n "$APP_IDENTIFIER" ]; then
    # Try to extract version from project if deployment variables not set
    PROJECT_FILE=$(find . -name "project.pbxproj" | head -1)
    if [ -n "$PROJECT_FILE" ] && [ -f "$PROJECT_FILE" ]; then
        CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJECT_FILE" 2>/dev/null | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')
        CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" 2>/dev/null | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')
        if [ -n "$CURRENT_VERSION" ] && [ -n "$CURRENT_BUILD" ]; then
            echo "║ 📱 Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
        fi
    fi
fi

echo "║ ⏱️  Total time: ${TOTAL_DEPLOYMENT_TIME} seconds"
echo "║ 📊 Progress: 100% (6/6 steps completed)"
echo "║ 📄 Session log: build/logs/$(basename "$LOG_FILE")"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

log_success "All deployment steps completed successfully!"
log_info "Check the output above for results and any error messages"

if [ "$DEBUG_MODE" = "true" ]; then
    log_debug "Debug information captured in log file for troubleshooting"
fi
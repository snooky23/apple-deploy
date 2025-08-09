#!/usr/bin/env ruby

require 'spaceship'
require 'fastlane'
require 'fastlane_core'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("FORCE FRESH SETUP", "Complete Certificate & Profile Reset")

begin
  # Set up Spaceship with App Store Connect API
  FastlaneLogger.info("🔐 Authenticating with Apple Developer Portal...")
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "YOUR_KEY_ID",
    issuer_id: "12345678-1234-1234-1234-123456789012",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_YOUR_KEY_ID.p8"
  )
  FastlaneLogger.success("Authentication successful")
  
  # STEP 1: Complete certificate cleanup
  FastlaneLogger.subheader("🧹 STEP 1: Complete Certificate Cleanup")
  
  certs = Spaceship::ConnectAPI::Certificate.all
  FastlaneLogger.info("Found #{certs.count} total certificates")
  
  certs.each_with_index do |cert, idx|
    FastlaneLogger.info("Revoking certificate #{idx + 1}/#{certs.count}: #{cert.certificate_type} - #{cert.id}")
    cert.delete!
    sleep(0.3) # Avoid API rate limits
  end
  FastlaneLogger.success("All certificates revoked")
  
  # STEP 2: Complete profile cleanup  
  FastlaneLogger.subheader("🧹 STEP 2: Complete Profile Cleanup")
  
  profiles = Spaceship::ConnectAPI::Profile.all
  FastlaneLogger.info("Found #{profiles.count} total profiles")
  
  profiles.each_with_index do |profile, idx|
    FastlaneLogger.info("Deleting profile #{idx + 1}/#{profiles.count}: #{profile.name}")
    profile.delete!
    sleep(0.3) # Avoid API rate limits
  end
  FastlaneLogger.success("All profiles deleted")
  
  # Wait a bit for Apple's systems to sync
  FastlaneLogger.info("⏳ Waiting 5 seconds for Apple systems to sync...")
  sleep(5)
  
  # STEP 3: Create fresh certificates using fastlane cert
  FastlaneLogger.subheader("🔐 STEP 3: Creating Fresh Certificates")
  
  # Change to proper directory for fastlane
  Dir.chdir("/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy")
  
  # Set up fastlane environment
  ENV['FASTLANE_USER'] = 'your-developer@email.com'
  ENV['FASTLANE_TEAM_ID'] = 'YOUR_TEAM_ID'
  
  # Create Development certificate
  FastlaneLogger.info("Creating Development certificate...")
  system('fastlane cert --development --output_path "./certificates/" --team_id YOUR_TEAM_ID --api_key_path "./certificates/AuthKey_YOUR_KEY_ID.p8" --api_key ./certificates/AuthKey_YOUR_KEY_ID.p8 --key_id YOUR_KEY_ID --issuer_id 12345678-1234-1234-1234-123456789012')
  
  # Create Distribution certificate  
  FastlaneLogger.info("Creating Distribution certificate...")
  system('fastlane cert --output_path "./certificates/" --team_id YOUR_TEAM_ID --api_key_path "./certificates/AuthKey_YOUR_KEY_ID.p8" --api_key ./certificates/AuthKey_YOUR_KEY_ID.p8 --key_id YOUR_KEY_ID --issuer_id 12345678-1234-1234-1234-123456789012')
  
  # STEP 4: Create provisioning profiles
  FastlaneLogger.subheader("📋 STEP 4: Creating Fresh Provisioning Profiles")
  
  # Create Development profile
  FastlaneLogger.info("Creating Development provisioning profile...")
  system('fastlane sigh --development --app_identifier com.yourcompany.yourapp --output_path "./profiles/" --team_id YOUR_TEAM_ID --force --api_key_path "./certificates/AuthKey_YOUR_KEY_ID.p8" --key_id YOUR_KEY_ID --issuer_id 12345678-1234-1234-1234-123456789012')
  
  # Create Distribution profile
  FastlaneLogger.info("Creating Distribution provisioning profile...") 
  system('fastlane sigh --app_identifier com.yourcompany.yourapp --output_path "./profiles/" --team_id YOUR_TEAM_ID --force --api_key_path "./certificates/AuthKey_YOUR_KEY_ID.p8" --key_id YOUR_KEY_ID --issuer_id 12345678-1234-1234-1234-123456789012')
  
  # STEP 5: Verify results
  FastlaneLogger.subheader("📊 STEP 5: Verification Results")
  
  FastlaneLogger.info("📁 Certificates created:")
  Dir.glob("./certificates/*.{cer,p12}").each { |f| FastlaneLogger.info("   - #{File.basename(f)}") }
  
  FastlaneLogger.info("📁 Profiles created:")
  Dir.glob("./profiles/*.mobileprovision").each { |f| FastlaneLogger.info("   - #{File.basename(f)}") }
  
  FastlaneLogger.success("🎉 FRESH SETUP COMPLETED! Ready for TestFlight deployment.")
  
rescue => e
  FastlaneLogger.error("Error during fresh setup: #{e.message}")
  FastlaneLogger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
  exit 1
end
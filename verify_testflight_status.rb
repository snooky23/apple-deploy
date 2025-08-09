#!/usr/bin/env ruby

# TestFlight Upload Verification Script
# This script checks the status of recent TestFlight uploads

require 'spaceship'
require 'json'
require_relative 'scripts/fastlane/modules/core/logger'

def verify_testflight_status
  FastlaneLogger.header("TestFlight Status Verification", "Checking upload status")
  
  # Configuration
  app_identifier = "com.voiceforms"
  api_key_path = "certificates/AuthKey_ZLDUP533YR.p8"
  api_key_id = "ZLDUP533YR" 
  api_issuer_id = "63cb40ec-3fb4-4e64-b8f9-1b10996adce6"
  
  begin
    # Authenticate with App Store Connect API
    FastlaneLogger.info("Authenticating with App Store Connect...")
    
    Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
      key_id: api_key_id,
      issuer_id: api_issuer_id,
      key_filepath: api_key_path
    )
    
    # Find the app
    FastlaneLogger.info("Looking for app: #{app_identifier}")
    app = Spaceship::ConnectAPI::App.find(app_identifier)
    
    unless app
      FastlaneLogger.error("App not found: #{app_identifier}")
      return
    end
    
    FastlaneLogger.success("Found app: #{app.name} (ID: #{app.id})")
    
    # Get recent builds
    FastlaneLogger.info("Fetching recent builds...")
    builds = Spaceship::ConnectAPI::Build.all(
      app_id: app.id,
      sort: "-uploadedDate",
      limit: 5
    )
    
    if builds.empty?
      FastlaneLogger.error("No builds found for this app")
      return
    end
    
    FastlaneLogger.subheader("Recent TestFlight Builds")
    
    builds.each_with_index do |build, index|
      status_emoji = case build.processing_state
                    when "VALID" then "✅"
                    when "PROCESSING" then "⏳"
                    when "INVALID" then "❌"
                    else "❓"
                    end
      
      FastlaneLogger.info("#{index + 1}. #{status_emoji} Build #{build.version} (#{build.build_number})")
      FastlaneLogger.info("   Uploaded: #{build.uploaded_date}")
      FastlaneLogger.info("   Status: #{build.processing_state}")
      
      if build.processing_state == "PROCESSING"
        FastlaneLogger.warn("   Still processing - check again in 5-10 minutes")
      elsif build.processing_state == "VALID"
        FastlaneLogger.success("   Ready for testing!")
      elsif build.processing_state == "INVALID"
        FastlaneLogger.error("   Processing failed - check App Store Connect for details")
      end
      
      # Removed blank line
    end
    
    # Show latest build details
    latest_build = builds.first
    FastlaneLogger.subheader("Latest Build Summary")
    FastlaneLogger.info("App: #{app.name}")
    FastlaneLogger.info("Version: #{latest_build.version} (#{latest_build.build_number})")
    FastlaneLogger.info("Upload Date: #{latest_build.uploaded_date}")
    FastlaneLogger.info("Processing State: #{latest_build.processing_state}")
    FastlaneLogger.info("TestFlight URL: https://appstoreconnect.apple.com/apps/#{app.id}/testflight")
    
    # Log success
    if latest_build.processing_state == "VALID" || latest_build.processing_state == "PROCESSING"
      log_entry = "#{Time.now.iso8601}: VERIFIED - Build #{latest_build.build_number} status: #{latest_build.processing_state}"
      File.open("certificates/testflight_uploads.log", "a") { |f| f.puts log_entry }
      FastlaneLogger.success("Status logged to certificates/testflight_uploads.log")
    end
    
  rescue => e
    FastlaneLogger.error("Error verifying TestFlight status: #{e.message}")
    FastlaneLogger.info("This might be due to API authentication issues or network connectivity")
  end
end

# Run verification
verify_testflight_status
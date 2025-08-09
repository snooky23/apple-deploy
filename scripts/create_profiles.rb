#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Create Provisioning Profiles", "API Authentication with Spaceship")

begin
  # Set up Spaceship with App Store Connect API
  FastlaneLogger.info("🔐 Authenticating with Apple Developer Portal...")
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "ZLDUP533YR",
    issuer_id: "63cb40ec-3fb4-4e64-b8f9-1b10996adce6",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_ZLDUP533YR.p8"
  )
  FastlaneLogger.success("Authentication successful")
  
  # Get the bundle ID
  FastlaneLogger.info("📱 Finding Bundle ID for com.voiceforms...")
  bundle_ids = Spaceship::ConnectAPI::BundleId.all
  bundle_id = bundle_ids.find { |bid| bid.identifier == "com.voiceforms" }
  
  if bundle_id.nil?
    FastlaneLogger.warn("Bundle ID com.voiceforms not found. Creating it...")
    bundle_id = Spaceship::ConnectAPI::BundleId.create(
      identifier: "com.voiceforms",
      name: "Voice Forms",
      platform: "IOS"
    )
    FastlaneLogger.success("Bundle ID created: #{bundle_id.id}")
  else
    FastlaneLogger.success("Bundle ID found: #{bundle_id.id}")
  end
  
  # Get certificates
  FastlaneLogger.subheader("🔐 Finding Certificates")
  certificates = Spaceship::ConnectAPI::Certificate.all
  dev_cert = certificates.find { |cert| cert.certificate_type == "IOS_DEVELOPMENT" }
  dist_cert = certificates.find { |cert| cert.certificate_type == "IOS_DISTRIBUTION" }
  
  FastlaneLogger.info("Development Certificate: #{dev_cert&.id || 'Not found'}")
  FastlaneLogger.info("Distribution Certificate: #{dist_cert&.id || 'Not found'}")
  
  # Get devices (for development profile)
  FastlaneLogger.subheader("📱 Getting Devices")
  devices = Spaceship::ConnectAPI::Device.all
  FastlaneLogger.info("Found #{devices.count} registered devices")
  
  # Create Development Profile
  if dev_cert
    FastlaneLogger.subheader("📋 Creating Development Provisioning Profile")
    begin
      dev_profile = Spaceship::ConnectAPI::Profile.create(
        name: "com.voiceforms Development",
        profile_type: "IOS_APP_DEVELOPMENT",
        bundle_id_id: bundle_id.id,
        certificate_ids: [dev_cert.id],
        device_ids: devices.map(&:id)
      )
      
      # Download the profile
      profile_content = dev_profile.download
      dev_profile_path = "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/profiles/#{dev_profile.name.gsub(' ', '_')}.mobileprovision"
      File.write(dev_profile_path, profile_content)
      
      FastlaneLogger.success("Development Profile Created: #{dev_profile.name}")
      FastlaneLogger.info("   Saved to: #{dev_profile_path}")
    rescue => e
      FastlaneLogger.error("Development profile creation failed: #{e.message}")
    end
  end
  
  # Create Distribution Profile
  if dist_cert
    FastlaneLogger.subheader("📋 Creating Distribution Provisioning Profile")
    begin
      dist_profile = Spaceship::ConnectAPI::Profile.create(
        name: "com.voiceforms AppStore",
        profile_type: "IOS_APP_STORE",
        bundle_id_id: bundle_id.id,
        certificate_ids: [dist_cert.id]
      )
      
      # Download the profile
      profile_content = dist_profile.download
      dist_profile_path = "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/profiles/#{dist_profile.name.gsub(' ', '_')}.mobileprovision"
      File.write(dist_profile_path, profile_content)
      
      FastlaneLogger.success("Distribution Profile Created: #{dist_profile.name}")
      FastlaneLogger.info("   Saved to: #{dist_profile_path}")
    rescue => e
      FastlaneLogger.error("Distribution profile creation failed: #{e.message}")
    end
  end
  
  FastlaneLogger.subheader("📊 Final Results")
  FastlaneLogger.info("Certificates:")
  Dir.glob("/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/*.{cer,p12}").each { |f| FastlaneLogger.info("   - #{File.basename(f)}") }
  FastlaneLogger.info("Profiles:")
  Dir.glob("/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/profiles/*.mobileprovision").each { |f| FastlaneLogger.info("   - #{File.basename(f)}") }
  
  FastlaneLogger.success("🎉 Provisioning Profile Creation Complete!")
  
rescue => e
  FastlaneLogger.error(e.message)
  FastlaneLogger.error("Backtrace: #{e.backtrace.first(3).join("\n")}")
  exit 1
end
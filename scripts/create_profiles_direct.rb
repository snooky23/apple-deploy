#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Direct Provisioning Profile Creation", "Creating profiles via Apple Connect API")

begin
  # Set up Spaceship with App Store Connect API
  FastlaneLogger.info("🔐 Authenticating with Apple Developer Portal...")
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "ZLDUP533YR",
    issuer_id: "63cb40ec-3fb4-4e64-b8f9-1b10996adce6",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_ZLDUP533YR.p8"
  )
  FastlaneLogger.success("Authentication successful")
  
  # Get bundle ID
  FastlaneLogger.info("📱 Getting Bundle ID for com.voiceforms...")
  bundle_ids = Spaceship::ConnectAPI::BundleId.all
  bundle_id = bundle_ids.find { |bid| bid.identifier == "com.voiceforms" }
  
  if bundle_id
    FastlaneLogger.success("Bundle ID found: #{bundle_id.id} (#{bundle_id.identifier})")
  else
    FastlaneLogger.error("Bundle ID not found")
    exit 1
  end
  
  # Get all certificates
  FastlaneLogger.subheader("🔐 Getting Certificates")
  certificates = Spaceship::ConnectAPI::Certificate.all
  
  FastlaneLogger.info("Found #{certificates.count} certificates:")
  certificates.each_with_index do |cert, idx|
    FastlaneLogger.info("  #{idx + 1}. #{cert.certificate_type}: #{cert.id}")
  end
  
  # Find certificates by actual returned types
  dev_cert = certificates.find { |cert| cert.certificate_type == "DEVELOPMENT" }
  dist_cert = certificates.find { |cert| cert.certificate_type == "DISTRIBUTION" }
  
  FastlaneLogger.info("Target Certificates:")
  FastlaneLogger.info("Development: #{dev_cert&.id || 'Not found'}")
  FastlaneLogger.info("Distribution: #{dist_cert&.id || 'Not found'}")
  
  # Get all devices
  FastlaneLogger.subheader("📱 Getting Devices")
  devices = Spaceship::ConnectAPI::Device.all
  ios_devices = devices.select { |d| d.platform == "IOS" }
  FastlaneLogger.info("Found #{ios_devices.count} iOS devices")
  
  profiles_dir = "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/profiles"
  
  # Create Development Profile
  if dev_cert && !ios_devices.empty?
    FastlaneLogger.subheader("📋 Creating Development Provisioning Profile")
    begin
      dev_profile = Spaceship::ConnectAPI::Profile.create(
        name: "Voice Forms Development",
        profile_type: "IOS_APP_DEVELOPMENT", 
        bundle_id_id: bundle_id.id,
        certificate_ids: [dev_cert.id],
        device_ids: ios_devices.map(&:id)
      )
      
      # Download and save profile
      begin
        profile_content = dev_profile.profile_content
        profile_path = File.join(profiles_dir, "Voice_Forms_Development.mobileprovision")
        File.write(profile_path, profile_content)
      rescue => download_error
        FastlaneLogger.warn("Profile created but download failed: #{download_error.message}")
        FastlaneLogger.info("   Profile ID: #{dev_profile.id}")
      end
      
      FastlaneLogger.success("Development Profile Created!")
      FastlaneLogger.info("   Name: #{dev_profile.name}")
      FastlaneLogger.info("   Saved: #{profile_path}")
      
    rescue => e
      FastlaneLogger.error("Development profile failed: #{e.message}")
    end
  else
    FastlaneLogger.error("Cannot create development profile - missing certificate or no devices")
  end
  
  # Create Distribution Profile  
  if dist_cert
    FastlaneLogger.subheader("🚀 Creating Distribution Provisioning Profile")
    begin
      dist_profile = Spaceship::ConnectAPI::Profile.create(
        name: "Voice Forms AppStore",
        profile_type: "IOS_APP_STORE",
        bundle_id_id: bundle_id.id,
        certificate_ids: [dist_cert.id]
      )
      
      # Download and save profile
      begin
        profile_content = dist_profile.profile_content
        profile_path = File.join(profiles_dir, "Voice_Forms_AppStore.mobileprovision")
        File.write(profile_path, profile_content)
      rescue => download_error
        FastlaneLogger.warn("Profile created but download failed: #{download_error.message}")
        FastlaneLogger.info("   Profile ID: #{dist_profile.id}")
      end
      
      FastlaneLogger.success("Distribution Profile Created!")
      FastlaneLogger.info("   Name: #{dist_profile.name}")
      FastlaneLogger.info("   Saved: #{profile_path}")
      
    rescue => e
      FastlaneLogger.error("Distribution profile failed: #{e.message}")
    end
  else
    FastlaneLogger.error("Cannot create distribution profile - missing certificate")
  end
  
  FastlaneLogger.subheader("📊 Final Status")
  FastlaneLogger.info("Profiles created in: #{profiles_dir}")
  Dir.glob(File.join(profiles_dir, "*.mobileprovision")).each do |file|
    FastlaneLogger.info("  ✅ #{File.basename(file)}")
  end
  
rescue => e
  FastlaneLogger.error(e.message)
  FastlaneLogger.error("Backtrace: #{e.backtrace.first(3).join("\n")}") 
  exit 1
end
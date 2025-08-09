#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Download Existing Provisioning Profiles", "Fetch profiles from Apple Developer Portal")

begin
  # Set up Spaceship with App Store Connect API
  FastlaneLogger.info("🔐 Authenticating with Apple Developer Portal...")
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "ZLDUP533YR",
    issuer_id: "63cb40ec-3fb4-4e64-b8f9-1b10996adce6",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_ZLDUP533YR.p8"
  )
  FastlaneLogger.success("Authentication successful")
  
  # Get all profiles
  FastlaneLogger.subheader("📋 Getting All Provisioning Profiles")
  profiles = Spaceship::ConnectAPI::Profile.all
  
  FastlaneLogger.info("Found #{profiles.count} total profiles:")
  profiles.each_with_index do |profile, idx|
    FastlaneLogger.info("  #{idx + 1}. #{profile.name} (#{profile.profile_type})")
  end
  
  # Find Voice Forms profiles
  voice_forms_profiles = profiles.select { |p| p.name.include?("Voice Forms") || p.name.include?("com.voiceforms") }
  
  FastlaneLogger.info("🎯 Voice Forms Profiles Found: #{voice_forms_profiles.count}")
  
  profiles_dir = "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/profiles"
  
  voice_forms_profiles.each do |profile|
    FastlaneLogger.info("📥 Downloading: #{profile.name}")
    
    begin
      # Use fastlane sigh to download the profile
      profile_name_safe = profile.name.gsub(/[^A-Za-z0-9_\-]/, '_')
      profile_path = File.join(profiles_dir, "#{profile_name_safe}.mobileprovision")
      
      # Create a temporary download using fastlane
      system("fastlane run download_provisioning_profiles app_identifier:com.voiceforms team_id:NA5574MSN5 output_path:#{profiles_dir}")
      
      FastlaneLogger.success("Profile download attempted")
      
    rescue => e
      FastlaneLogger.error("Download failed: #{e.message}")
    end
  end
  
  FastlaneLogger.subheader("📊 Final Status")
  FastlaneLogger.info("Checking profiles directory: #{profiles_dir}")
  profile_files = Dir.glob(File.join(profiles_dir, "*.mobileprovision"))
  
  if profile_files.any?
    FastlaneLogger.success("Profiles found:")
    profile_files.each do |file|
      file_size = File.size(file)
      FastlaneLogger.info("  ✅ #{File.basename(file)} (#{file_size} bytes)")
    end
  else
    FastlaneLogger.warn("No .mobileprovision files found")
    
    # Try alternative approach - fastlane sigh download
    FastlaneLogger.info("🔄 Trying alternative download method...")
    system("cd /Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy && fastlane run sigh download_all:true output_path:./profiles/")
    
    # Check again
    profile_files = Dir.glob(File.join(profiles_dir, "*.mobileprovision"))
    if profile_files.any?
      FastlaneLogger.success("Alternative method worked! Profiles:")
      profile_files.each do |file|
        FastlaneLogger.info("  ✅ #{File.basename(file)}")
      end
    end
  end
  
rescue => e
  FastlaneLogger.error(e.message)
  FastlaneLogger.error("Backtrace: #{e.backtrace.first(3).join("\n")}")
  exit 1
end
#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Certificate Status Check", "Checking current certificate status")

begin
  # Set up Spaceship with App Store Connect API
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "YOUR_KEY_ID",
    issuer_id: "12345678-1234-1234-1234-123456789012",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_YOUR_KEY_ID.p8"
  )
  
  # Get all certificates
  certificates = Spaceship::ConnectAPI::Certificate.all
  FastlaneLogger.info("Found #{certificates.count} total certificates:")
  
  certificates.each do |cert|
    FastlaneLogger.info("  - #{cert.certificate_type}: #{cert.id} (Created: #{cert.created_date})")
  end
  
  # Get profiles
  profiles = Spaceship::ConnectAPI::Profile.all
  FastlaneLogger.info("Found #{profiles.count} total profiles:")
  
  profiles.each do |profile|
    FastlaneLogger.info("  - #{profile.name}: #{profile.profile_type}")
  end
  
rescue => e
  FastlaneLogger.error(e.message)
end
#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Certificate Status Check", "Checking current certificate status")

begin
  # Set up Spaceship with App Store Connect API
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "ZLDUP533YR",
    issuer_id: "63cb40ec-3fb4-4e64-b8f9-1b10996adce6",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_ZLDUP533YR.p8"
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
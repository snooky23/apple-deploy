#!/usr/bin/env ruby

require 'spaceship'
require_relative 'fastlane/modules/core/logger'

FastlaneLogger.header("Manual Certificate Cleanup", "Apple Developer Portal Certificate Management")

begin
  # Set up Spaceship with App Store Connect API
  FastlaneLogger.info("🔐 Authenticating with Apple Developer Portal...")
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
    key_id: "ZLDUP533YR",
    issuer_id: "63cb40ec-3fb4-4e64-b8f9-1b10996adce6",
    filepath: "/Users/avilevin/Workspace/iOS/Personal/ios-fastlane-auto-deploy/certificates/AuthKey_ZLDUP533YR.p8"
  )
  FastlaneLogger.success("Authentication successful")
  
  # Get all certificates for this team
  FastlaneLogger.subheader("📋 Fetching existing certificates")
  certs = Spaceship::ConnectAPI::Certificate.all
  
  dev_certs = certs.select { |cert| cert.certificate_type == "IOS_DEVELOPMENT" }
  dist_certs = certs.select { |cert| cert.certificate_type == "IOS_DISTRIBUTION" }
  
  FastlaneLogger.info("Found #{dev_certs.count} Development certificates")
  FastlaneLogger.info("Found #{dist_certs.count} Distribution certificates")
  
  # List certificates with creation dates
  if dev_certs.any?
    FastlaneLogger.info("Development Certificates:")
    dev_certs.each_with_index do |cert, idx|
      FastlaneLogger.info("  #{idx + 1}. ID: #{cert.id} - Created: #{cert.created_date}")
    end
  end
  
  if dist_certs.any?
    FastlaneLogger.info("Distribution Certificates:")
    dist_certs.each_with_index do |cert, idx|
      FastlaneLogger.info("  #{idx + 1}. ID: #{cert.id} - Created: #{cert.created_date}")
    end
  end
  
  # Revoke ALL certificates to ensure we can create fresh ones
  FastlaneLogger.subheader("🗑️  Revoking ALL certificates to free up slots")
  
  dev_certs.each_with_index do |cert, idx|
    FastlaneLogger.info("Revoking Development certificate #{idx + 1}/#{dev_certs.count}...")
    cert.delete!
    FastlaneLogger.success("Revoked Development certificate #{cert.id}")
    sleep(0.5) # Small delay to avoid API rate limits
  end
  
  dist_certs.each_with_index do |cert, idx|
    FastlaneLogger.info("Revoking Distribution certificate #{idx + 1}/#{dist_certs.count}...")
    cert.delete!
    FastlaneLogger.success("Revoked Distribution certificate #{cert.id}")
    sleep(0.5) # Small delay to avoid API rate limits
  end
  
  FastlaneLogger.success("🎉 Certificate cleanup completed successfully!")
  FastlaneLogger.success("✅ All certificate slots are now available")
  FastlaneLogger.info("🚀 Ready to run fresh certificate and profile creation")
  
rescue => e
  FastlaneLogger.error("Error during cleanup: #{e.message}")
  FastlaneLogger.error("Backtrace: #{e.backtrace.join("\n")}")
  exit 1
end
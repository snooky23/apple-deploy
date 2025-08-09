#!/usr/bin/env ruby

require 'spaceship'
require 'timeout'
require_relative 'scripts/fastlane/modules/core/logger'

# Test App Store Connect API credentials
def test_api_credentials(key_id:, issuer_id:, key_filepath:, app_identifier:)
  FastlaneLogger.header("App Store Connect API Test", "Testing API credentials")
  FastlaneLogger.info("Key ID: #{key_id}")
  FastlaneLogger.info("Issuer ID: #{issuer_id}")
  FastlaneLogger.info("Key file: #{key_filepath}")
  FastlaneLogger.info("App ID: #{app_identifier}")
  
  begin
    # Test file existence
    unless File.exist?(key_filepath)
      FastlaneLogger.error("API key file not found: #{key_filepath}")
      return false
    end
    FastlaneLogger.success("API key file exists (#{File.size(key_filepath)} bytes)")
    
    # Test API authentication with timeout
    FastlaneLogger.subheader("Testing API authentication")
    
    begin
      Timeout::timeout(30) do
        # Set up API token
        token = Spaceship::ConnectAPI::Token.create(
          key_id: key_id,
          issuer_id: issuer_id,
          key_filepath: key_filepath
        )
        
        Spaceship::ConnectAPI.token = token
        FastlaneLogger.success("API token created successfully")
        
        # Test basic API call
        FastlaneLogger.info("Testing API access - fetching apps...")
        apps = Spaceship::ConnectAPI::App.all
        FastlaneLogger.success("API call successful - found #{apps.length} apps")
        
        # Test specific app
        if app_identifier
          FastlaneLogger.info("Looking for specific app: #{app_identifier}")
          app = Spaceship::ConnectAPI::App.find(app_identifier)
          if app
            FastlaneLogger.success("App found: #{app.name} (#{app.bundle_id})")
            
            # Test TestFlight builds access
            FastlaneLogger.info("Testing TestFlight builds access...")
            builds = app.get_builds(limit: 1)
            if builds && builds.any?
              latest_build = builds.first
              FastlaneLogger.success("TestFlight access confirmed - latest build: #{latest_build.build_number}")
            else
              FastlaneLogger.warn("No builds found (app may not have any TestFlight builds yet)")
            end
          else
            FastlaneLogger.error("App not found: #{app_identifier}")
            FastlaneLogger.error("This could mean:")
            FastlaneLogger.error("  - App doesn't exist on App Store Connect")
            FastlaneLogger.error("  - API key doesn't have access to this app")
            FastlaneLogger.error("  - Bundle ID is incorrect")
            return false
          end
        end
      end
    rescue Timeout::Error
      FastlaneLogger.error("API call timed out after 30 seconds")
      FastlaneLogger.error("This could indicate:")
      FastlaneLogger.error("  - Network connectivity issues")
      FastlaneLogger.error("  - Invalid API credentials")
      FastlaneLogger.error("  - App Store Connect API service issues")
      return false
    end
    
    FastlaneLogger.success("All API credential tests passed!")
    return true
    
  rescue => e
    FastlaneLogger.error("API credential test failed: #{e.message}")
    FastlaneLogger.subheader("Troubleshooting steps")
    FastlaneLogger.info("1. Verify the API key was downloaded correctly from App Store Connect")
    FastlaneLogger.info("2. Check that the Key ID matches the filename")
    FastlaneLogger.info("3. Confirm the Issuer ID is correct (from App Store Connect > Users and Access > Keys)")
    FastlaneLogger.info("4. Ensure the API key has 'App Manager' role or appropriate permissions")
    FastlaneLogger.info("5. Verify the app exists on App Store Connect")
    return false
  end
end

# Run the test
if ARGV.length >= 4
  key_id = ARGV[0]
  issuer_id = ARGV[1] 
  key_filepath = ARGV[2]
  app_identifier = ARGV[3]
  
  test_api_credentials(
    key_id: key_id,
    issuer_id: issuer_id, 
    key_filepath: key_filepath,
    app_identifier: app_identifier
  )
else
  FastlaneLogger.error("Usage: ruby test_api_key.rb <key_id> <issuer_id> <key_filepath> <app_identifier>")
  exit 1
end
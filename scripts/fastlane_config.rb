# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools
#
# For a list of all available actions, check out
#     https://docs.fastlane.tools/actions
#
# For a list of all available plugins, check out
#     https://docs.fastlane.tools/plugins/available-plugins

# Uncomment the line if you want fastlane to automatically update itself
# update_fastlane

default_platform(:ios)

platform :ios do
  desc "Create certificates and provisioning profiles"
  lane :setup_certificates do |options|
    # Validate required parameters
    UI.user_error!("Missing app_identifier") unless options[:app_identifier]
    UI.user_error!("Missing apple_id") unless options[:apple_id]
    UI.user_error!("Missing team_id") unless options[:team_id]
    UI.user_error!("Missing api_key_path") unless options[:api_key_path]
    UI.user_error!("Missing api_key_id") unless options[:api_key_id]
    UI.user_error!("Missing api_issuer_id") unless options[:api_issuer_id]
    
    UI.message("🚀 Starting certificate and provisioning profile setup...")
    UI.message("📱 App Identifier: #{options[:app_identifier]}")
    UI.message("👤 Apple ID: #{options[:apple_id]}")
    UI.message("🏢 Team ID: #{options[:team_id]}")
    
    # Create output directories
    sh("mkdir -p ../certificates")
    sh("mkdir -p ../profiles")
    
    # Set up App Store Connect API authentication
    app_store_connect_api_key(
      key_id: options[:api_key_id],
      issuer_id: options[:api_issuer_id],
      key_filepath: options[:api_key_path]
    )
    
    UI.message("🔐 Creating Development Certificate...")
    # Create or get development certificate
    cert(
      development: true,
      output_path: "../certificates/",
      team_id: options[:team_id],
      username: options[:apple_id]
    )
    
    UI.message("🏭 Creating Distribution Certificate...")
    # Create or get distribution certificate
    cert(
      development: false,
      output_path: "../certificates/",
      team_id: options[:team_id],
      username: options[:apple_id]
    )
    
    UI.message("📋 Creating Development Provisioning Profile...")
    # Create development provisioning profile
    sigh(
      app_identifier: options[:app_identifier],
      development: true,
      output_path: "../profiles/",
      team_id: options[:team_id],
      username: options[:apple_id],
      force: false # Don't recreate if already exists
    )
    
    UI.message("🚀 Creating Distribution Provisioning Profile...")
    # Create distribution provisioning profile
    sigh(
      app_identifier: options[:app_identifier],
      development: false,
      output_path: "../profiles/",
      team_id: options[:team_id],
      username: options[:apple_id],
      force: false # Don't recreate if already exists
    )
    
    UI.success("✅ All certificates and provisioning profiles created successfully!")
    UI.message("📁 Certificates saved to: ./certificates/")
    UI.message("📁 Provisioning profiles saved to: ./profiles/")
  end
  
  desc "Export certificates to p12 format"
  lane :export_p12 do |options|
    password = options[:password] || "fastlane123"
    
    UI.message("🔐 Exporting certificates to P12 format...")
    UI.message("🔑 Using password: #{password}")
    
    # Create certificates directory if it doesn't exist
    sh("mkdir -p ../certificates")
    
    begin
      UI.message("📱 Exporting Development Certificate...")
      # Find and export development certificate
      dev_cert_name = sh("security find-certificate -c 'iPhone Developer' -Z | grep SHA-1 | head -1 | cut -d' ' -f3", log: false).strip
      if dev_cert_name && !dev_cert_name.empty?
        sh("security export -k login.keychain -t certs -f pkcs12 -o ../certificates/development.p12 -P '#{password}' -Z #{dev_cert_name}")
        UI.success("✅ Development certificate exported to: ./certificates/development.p12")
      else
        UI.error("❌ Development certificate not found in keychain")
      end
    rescue => e
      UI.error("❌ Failed to export development certificate: #{e.message}")
    end
    
    begin
      UI.message("🏭 Exporting Distribution Certificate...")
      # Find and export distribution certificate
      dist_cert_name = sh("security find-certificate -c 'iPhone Distribution' -Z | grep SHA-1 | head -1 | cut -d' ' -f3", log: false).strip
      if dist_cert_name && !dist_cert_name.empty?
        sh("security export -k login.keychain -t certs -f pkcs12 -o ../certificates/distribution.p12 -P '#{password}' -Z #{dist_cert_name}")
        UI.success("✅ Distribution certificate exported to: ./certificates/distribution.p12")
      else
        UI.error("❌ Distribution certificate not found in keychain")
      end
    rescue => e
      UI.error("❌ Failed to export distribution certificate: #{e.message}")
    end
    
    UI.success("🎉 P12 export process completed!")
  end
  
  desc "Clean up certificates and provisioning profiles"
  lane :cleanup do
    UI.message("🧹 Cleaning up certificates and profiles...")
    sh("rm -rf ../certificates")
    sh("rm -rf ../profiles")
    UI.success("✅ Cleanup completed!")
  end
  
  desc "Show current certificates and profiles"
  lane :status do
    UI.message("📋 Current Certificates in Keychain:")
    sh("security find-certificate -c 'iPhone' -p | openssl x509 -text | grep 'Subject:' || echo 'No iPhone certificates found'")
    
    UI.message("📁 Local Certificate Files:")
    if File.directory?("../certificates")
      sh("ls -la ../certificates/ || echo 'No certificate files found'")
    else
      UI.message("No certificates directory found")
    end
    
    UI.message("📁 Local Provisioning Profile Files:")
    if File.directory?("../profiles")
      sh("ls -la ../profiles/ || echo 'No profile files found'")
    else
      UI.message("No profiles directory found")
    end
  end
end